import os
import re
import json
import cv2
import numpy as np
import pytesseract
from PIL import Image
import pandas as pd
from datetime import datetime
import logging
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict

# ========================
# CONFIGURATION
# ========================
BASE_DIR = r"D:\nutriplan-ai\ml-engine"
DATA_DIR = os.path.join(BASE_DIR, "data")
HANDWRITTEN_DIR = os.path.join(DATA_DIR, "handwritten")
DOCTORS_DATASET_DIR = os.path.join(DATA_DIR, "Doctor's Handwritten Prescription BD dataset")
OUTPUT_DIR = os.path.join(DATA_DIR, "ehr")
OUTPUT_JSON = os.path.join(OUTPUT_DIR, "prescription_parsed.json")
UNIFIED_EHR = os.path.join(OUTPUT_DIR, "unified_ehr.json")

# Tesseract configuration (update with your path if needed)
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Create directories if they don't exist
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(HANDWRITTEN_DIR, exist_ok=True)

# ========================
# MEDICAL KNOWLEDGE BASE
# ========================
MEDICAL_TERMS = {
    'medications': [
        'metformin', 'amlodipine', 'lisinopril', 'atorvastatin', 'albuterol',
        'levothyroxine', 'sertraline', 'insulin', 'losartan', 'omeprazole',
        'aspirin', 'ibuprofen', 'acetaminophen', 'warfarin', 'prednisone',
        'metoprolol', 'hydrochlorothiazide', 'simvastatin', 'paracetamol',
        'atenolol', 'furosemide', 'citalopram', 'escitalopram', 'amlodipine',
        'carvedilol', 'diazepam', 'lorazepam', 'clonazepam', 'tramadol',
        'codeine', 'morphine', 'oxycodone', 'hydromorphone', 'gabapentin'
    ],
    'diseases': [
        'diabetes', 'hypertension', 'hyperlipidemia', 'asthma', 'arthritis',
        'osteoporosis', 'depression', 'anxiety', 'hypothyroidism', 'anemia',
        'migraine', 'copd', 'heart disease', 'kidney disease', 'cancer',
        'alzheimer', 'parkinson', 'epilepsy', 'stroke', 'tuberculosis',
        'hepatitis', 'hiv', 'aids', 'pneumonia', 'bronchitis'
    ],
    'allergies': [
        'penicillin', 'peanuts', 'shellfish', 'eggs', 'soy', 'dairy', 'gluten',
        'sulfa', 'aspirin', 'latex', 'pollen', 'dust mites', 'pet dander',
        'iodine', 'codeine', 'morphine', 'sulfonamides', 'tetracycline'
    ],
    'dosage_units': [
        'mg', 'g', 'ml', 'l', 'tsp', 'tbsp', 'tab', 'caps', 'units', 'iu',
        'mcg', 'μg', 'cc', 'drop', 'patch', 'puff', 'injection'
    ],
    'frequency': [
        'daily', 'bid', 'tid', 'qid', 'qhs', 'qod', 'prn', 'weekly', 'monthly',
        'hourly', 'every', 'times', 'x/day', 'x/week', 'x/month'
    ],
    'duration_units': [
        'days', 'weeks', 'months', 'years', 'doses', 'applications', 'until finished',
        'as needed'
    ]
}

# ========================
# LOGGING CONFIGURATION
# ========================
logging.basicConfig(
    filename=os.path.join(BASE_DIR, 'logs', 'ocr_extractor.log'),
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('OCR Extractor')

# ========================
# IMAGE PROCESSING FUNCTIONS
# ========================
def preprocess_image(image_path):
    """
    Apply advanced preprocessing to enhance OCR accuracy
    Steps: Resize, Grayscale, Denoising, Thresholding, Dilation, Erosion
    """
    try:
        # Read image
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Could not read image: {image_path}")
        
        # Resize image for consistent processing
        img = cv2.resize(img, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_CUBIC)
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply bilateral filter for noise reduction while preserving edges
        denoised = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Adaptive thresholding
        thresh = cv2.adaptiveThreshold(
            denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY, 11, 2
        )
        
        # Morphological operations to enhance text
        kernel = np.ones((1, 1), np.uint8)
        dilated = cv2.dilate(thresh, kernel, iterations=1)
        eroded = cv2.erode(dilated, kernel, iterations=1)
        
        # Apply sharpening
        kernel_sharp = np.array([[-1, -1, -1], 
                                [-1, 9, -1], 
                                [-1, -1, -1]])
        sharpened = cv2.filter2D(eroded, -1, kernel_sharp)
        
        return sharpened
    except Exception as e:
        logger.error(f"Image preprocessing failed: {str(e)}")
        return None

# ========================
# OCR & TEXT PROCESSING
# ========================
def extract_text(image_path, use_easyocr=False):
    """
    Extract text from image using OCR
    Supports both Tesseract and EasyOCR (if installed)
    """
    try:
        # Preprocess image
        processed_img = preprocess_image(image_path)
        if processed_img is None:
            return ""
        
        # Use EasyOCR if requested and available
        if use_easyocr:
            try:
                import easyocr
                reader = easyocr.Reader(['en'])
                result = reader.readtext(processed_img, detail=0)
                return " ".join(result)
            except ImportError:
                logger.warning("EasyOCR not installed. Falling back to Tesseract.")
        
        # Default to Tesseract
        custom_config = r'--oem 3 --psm 6 -c preserve_interword_spaces=1'
        text = pytesseract.image_to_string(
            processed_img, 
            config=custom_config,
            lang='eng'
        )
        return text.strip()
    except Exception as e:
        logger.error(f"OCR extraction failed: {str(e)}")
        return ""

def parse_prescription_text(text):
    """
    Parse extracted text to identify medical entities using advanced regex patterns
    and medical knowledge base
    """
    results = {
        "medications": [],
        "diseases": [],
        "allergies": [],
        "dosage_instructions": [],
        "patient_info": {},
        "doctor_info": {},
        "date": ""
    }
    
    try:
        if not text:
            return results
        
        # Normalize text for case-insensitive matching
        normalized_text = text.lower()
        
        # Extract date patterns (dd/mm/yyyy, mm/dd/yyyy, etc.)
        date_pattern = r'\b(\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4})\b'
        date_match = re.search(date_pattern, normalized_text)
        if date_match:
            results["date"] = date_match.group(1)
        
        # Extract patient name (simple pattern - can be enhanced)
        name_pattern = r'patient:\s*([a-z ]+)|name:\s*([a-z ]+)'
        name_match = re.search(name_pattern, normalized_text)
        if name_match:
            results["patient_info"]["name"] = name_match.group(1) or name_match.group(2) or ""
        
        # Extract patient age
        age_pattern = r'age:\s*(\d+)|y\/o:\s*(\d+)|years:\s*(\d+)'
        age_match = re.search(age_pattern, normalized_text)
        if age_match:
            results["patient_info"]["age"] = int(age_match.group(1) or age_match.group(2) or age_match.group(3) or 0)
        
        # Extract patient gender
        gender_pattern = r'gender:\s*([mf])|sex:\s*([mf])'
        gender_match = re.search(gender_pattern, normalized_text)
        if gender_match:
            results["patient_info"]["gender"] = gender_match.group(1) or gender_match.group(2) or ""
        
        # Extract doctor information
        doctor_pattern = r'dr\.?\s*([a-z. ]+)|doctor:\s*([a-z ]+)|physician:\s*([a-z ]+)'
        doctor_match = re.search(doctor_pattern, normalized_text, re.IGNORECASE)
        if doctor_match:
            results["doctor_info"]["name"] = doctor_match.group(1) or doctor_match.group(2) or doctor_match.group(3) or ""
        
        # Extract medications with dosage information
        med_pattern = r'(\b[a-z]+\b)\s*([\d.]+)\s*(' + '|'.join(MEDICAL_TERMS['dosage_units']) + r')\s*(' + '|'.join(MEDICAL_TERMS['frequency']) + r')\s*(' + '|'.join(MEDICAL_TERMS['duration_units']) + r')?'
        
        for match in re.finditer(med_pattern, normalized_text):
            med_name = match.group(1)
            # Validate medication name against known medications
            if med_name in MEDICAL_TERMS['medications']:
                results["medications"].append({
                    "name": med_name,
                    "dosage": f"{match.group(2)} {match.group(3)}",
                    "frequency": match.group(4),
                    "duration": match.group(5) or "until finished"
                })
        
        # Find additional medications without dosage info
        for med in MEDICAL_TERMS['medications']:
            if med in normalized_text and not any(m['name'] == med for m in results["medications"]):
                results["medications"].append({
                    "name": med,
                    "dosage": "",
                    "frequency": "",
                    "duration": ""
                })
        
        # Extract diseases
        for disease in MEDICAL_TERMS['diseases']:
            if re.search(rf'\b{disease}\b', normalized_text):
                results["diseases"].append(disease)
        
        # Extract allergies with context
        allergy_pattern = r'allerg(?:y|ies)\b.*?\bto\b\s+(.*?)(?:\.|\n|$)'
        for match in re.findall(allergy_pattern, normalized_text):
            for allergen in MEDICAL_TERMS['allergies']:
                if allergen in match:
                    results["allergies"].append(allergen)
        
        # Extract additional dosage instructions
        dosage_pattern = r'take\s+(\d+)\s+(' + '|'.join(MEDICAL_TERMS['dosage_units']) + r')\s+of\s+(\b[a-z]+\b)\s+(' + '|'.join(MEDICAL_TERMS['frequency']) + r')'
        for match in re.finditer(dosage_pattern, normalized_text):
            med_name = match.group(3)
            if med_name in MEDICAL_TERMS['medications']:
                results["dosage_instructions"].append({
                    "medication": med_name,
                    "instruction": f"Take {match.group(1)} {match.group(2)} {match.group(4)}"
                })
        
        return results
    except Exception as e:
        logger.error(f"Text parsing failed: {str(e)}")
        return results

# ========================
# DATA SAVING & INTEGRATION
# ========================
def save_extracted_data(data, output_path=OUTPUT_JSON, update_ehr=True):
    """
    Save parsed data to JSON file and optionally update unified EHR
    """
    try:
        # Save individual prescription data
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        logger.info(f"Saved prescription data to {output_path}")
        
        # Update unified EHR if requested
        if update_ehr and os.path.exists(UNIFIED_EHR):
            with open(UNIFIED_EHR, 'r+') as ehr_file:
                try:
                    ehr_data = json.load(ehr_file)
                except json.JSONDecodeError:
                    ehr_data = []
                
                # Find existing entry or create new
                patient_name = data.get("patient_info", {}).get("name", "")
                existing_index = next((i for i, item in enumerate(ehr_data) 
                                      if item.get("name", "") == patient_name), -1)
                
                if existing_index >= 0:
                    # Update existing record
                    record = ehr_data[existing_index]
                    record["medications"] = list(set(record.get("medications", []) + 
                                                    [m["name"] for m in data["medications"]]))
                    record["medical_conditions"] = list(set(record.get("medical_conditions", []) + 
                                                          data["diseases"]))
                    record["allergies"] = list(set(record.get("allergies", []) + 
                                                 data["allergies"]))
                    record["last_updated"] = datetime.now().isoformat()
                    ehr_data[existing_index] = record
                else:
                    # Create new EHR entry
                    new_record = {
                        "user_id": f"user_{len(ehr_data)+1}",
                        "name": patient_name,
                        "age": data.get("patient_info", {}).get("age", None),
                        "gender": data.get("patient_info", {}).get("gender", ""),
                        "medical_conditions": data["diseases"],
                        "medications": [m["name"] for m in data["medications"]],
                        "allergies": data["allergies"],
                        "source_data": {
                            "prescription_text": json.dumps(data),
                            "last_updated": datetime.now().isoformat()
                        }
                    }
                    ehr_data.append(new_record)
                
                # Save updated EHR
                ehr_file.seek(0)
                json.dump(ehr_data, ehr_file, indent=2)
                ehr_file.truncate()
                logger.info(f"Updated unified EHR with data for {patient_name}")
        
        return True
    except Exception as e:
        logger.error(f"Data saving failed: {str(e)}")
        return False

# ========================
# BATCH PROCESSING
# ========================
def process_single_image(image_path):
    """Process a single image and return extracted data"""
    try:
        logger.info(f"Processing image: {image_path}")
        
        # Step 1: Extract text using OCR
        text = extract_text(image_path)
        if not text:
            logger.warning(f"No text extracted from {image_path}")
            return None
        
        # Step 2: Parse extracted text
        parsed_data = parse_prescription_text(text)
        
        # Add metadata
        parsed_data["source_file"] = os.path.basename(image_path)
        parsed_data["processing_date"] = datetime.now().isoformat()
        parsed_data["ocr_text"] = text[:500] + "..." if len(text) > 500 else text
        
        return parsed_data
    except Exception as e:
        logger.error(f"Error processing {image_path}: {str(e)}")
        return None

def batch_process_images(input_dirs=[HANDWRITTEN_DIR, DOCTORS_DATASET_DIR], 
                         output_file=OUTPUT_JSON, 
                         max_workers=4):
    """
    Process all images in specified directories using multithreading
    """
    try:
        # Collect all image files
        image_paths = []
        valid_extensions = ('.jpg', '.jpeg', '.png', '.tiff', '.bmp')
        
        for input_dir in input_dirs:
            if not os.path.exists(input_dir):
                logger.warning(f"Directory not found: {input_dir}")
                continue
                
            for root, _, files in os.walk(input_dir):
                for file in files:
                    if file.lower().endswith(valid_extensions):
                        image_paths.append(os.path.join(root, file))
        
        if not image_paths:
            logger.warning("No images found for processing")
            return []
        
        logger.info(f"Found {len(image_paths)} images for processing")
        
        # Process images in parallel
        all_results = []
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            results = executor.map(process_single_image, image_paths)
            for result in results:
                if result:
                    all_results.append(result)
        
        logger.info(f"Successfully processed {len(all_results)}/{len(image_paths)} images")
        
        # Save combined results
        if all_results:
            with open(output_file, 'w') as f:
                json.dump(all_results, f, indent=2)
            logger.info(f"Saved combined results to {output_file}")
            
            # Update EHR with all results
            for result in all_results:
                save_extracted_data(result, update_ehr=True)
        
        return all_results
    except Exception as e:
        logger.error(f"Batch processing failed: {str(e)}")
        return []

# ========================
# MAIN EXECUTION
# ========================
def main():
    print("Starting OCR Prescription Processing...")
    logger.info("==== OCR EXTRACTOR STARTED ====")
    
    # Process all images in batch mode
    processed_data = batch_process_images()
    
    print(f"\nProcessing complete. Results saved to {OUTPUT_JSON}")
    print(f"Total prescriptions processed: {len(processed_data)}")
    
    logger.info("==== OCR EXTRACTOR FINISHED ====")

if __name__ == "__main__":
    # Add this if using EasyOCR: pip install easyocr
    main()