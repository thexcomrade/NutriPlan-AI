import os
import re
import json
import pandas as pd
import numpy as np
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
import cv2
import logging
from datetime import datetime
from collections import defaultdict
import matplotlib.pyplot as plt
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import KMeans
import spacy
import warnings
warnings.filterwarnings('ignore')

# ========================
# CONFIGURATION
# ========================
BASE_DIR = r"D:\nutriplan-ai\ml-engine"
DATA_DIR = os.path.join(BASE_DIR, "data")
REPORT_DIR = os.path.join(DATA_DIR, "patient report")
EHR_DIR = os.path.join(DATA_DIR, "ehr")
EHR_FILE = os.path.join(EHR_DIR, "unified_ehr.json")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
LOG_DIR = os.path.join(BASE_DIR, "logs")

# Create necessary directories
for directory in [OUTPUT_DIR, LOG_DIR]:
    os.makedirs(directory, exist_ok=True)

# Tesseract configuration
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# ========================
# LOGGING CONFIGURATION
# ========================
logging.basicConfig(
    filename=os.path.join(LOG_DIR, 'report_analyzer.log'),
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='a'
)
logger = logging.getLogger('ReportAnalyzer')

# ========================
# MEDICAL KNOWLEDGE BASE
# ========================
MEDICAL_TERMS = {
    'conditions': [
        'diabetes', 'hypertension', 'hyperlipidemia', 'asthma', 'arthritis',
        'osteoporosis', 'depression', 'anxiety', 'hypothyroidism', 'anemia',
        'migraine', 'copd', 'heart disease', 'kidney disease', 'cancer',
        'alzheimer', 'parkinson', 'epilepsy', 'stroke', 'tuberculosis',
        'hepatitis', 'hiv', 'aids', 'pneumonia', 'bronchitis', 'obesity',
        'coronary artery disease', 'myocardial infarction', 'angina', 'arrhythmia'
    ],
    'medications': [
        'metformin', 'amlodipine', 'lisinopril', 'atorvastatin', 'albuterol',
        'levothyroxine', 'sertraline', 'insulin', 'losartan', 'omeprazole',
        'aspirin', 'ibuprofen', 'acetaminophen', 'warfarin', 'prednisone',
        'metoprolol', 'hydrochlorothiazide', 'simvastatin', 'paracetamol',
        'atenolol', 'furosemide', 'citalopram', 'escitalopram', 'amlodipine',
        'carvedilol', 'diazepam', 'lorazepam', 'clonazepam', 'tramadol'
    ],
    'allergies': [
        'penicillin', 'peanuts', 'shellfish', 'eggs', 'soy', 'dairy', 'gluten',
        'sulfa', 'aspirin', 'latex', 'pollen', 'dust mites', 'pet dander',
        'iodine', 'codeine', 'morphine', 'sulfonamides', 'tetracycline'
    ],
    'lab_tests': [
        'blood sugar', 'glucose', 'hba1c', 'cholesterol', 'triglycerides',
        'hdl', 'ldl', 'creatinine', 'urea', 'bilirubin', 'alt', 'ast',
        'alkaline phosphatase', 'hemoglobin', 'hematocrit', 'wbc', 'rbc',
        'platelets', 'tsh', 't3', 't4', 'vitamin d', 'vitamin b12', 'iron',
        'sodium', 'potassium', 'calcium', 'magnesium', 'crp', 'esr'
    ],
    'vitals': [
        'blood pressure', 'bp', 'heart rate', 'pulse', 'respiratory rate',
        'temperature', 'oxygen saturation', 'spO2', 'bmi', 'weight', 'height'
    ]
}

# ========================
# IMAGE PROCESSING FUNCTIONS
# ========================
def preprocess_image(image_path):
    """Enhance image quality for better OCR results"""
    try:
        # Open image
        img = Image.open(image_path)
        
        # Convert to grayscale
        if img.mode != 'L':
            img = img.convert('L')
        
        # Enhance contrast
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2.0)
        
        # Enhance sharpness
        enhancer = ImageEnhance.Sharpness(img)
        img = enhancer.enhance(2.0)
        
        # Apply slight blur to reduce noise
        img = img.filter(ImageFilter.MedianFilter(3))
        
        # Convert to numpy array for OpenCV processing
        img_array = np.array(img)
        
        # Apply adaptive thresholding
        thresh = cv2.adaptiveThreshold(
            img_array, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY, 11, 2
        )
        
        # Convert back to PIL Image
        processed_img = Image.fromarray(thresh)
        
        return processed_img
    except Exception as e:
        logger.error(f"Image preprocessing failed: {str(e)}")
        return None

def extract_text_from_image(image_path):
    """Extract text from medical report images using OCR"""
    try:
        # Preprocess image
        processed_img = preprocess_image(image_path)
        if processed_img is None:
            return ""
        
        # Use Tesseract with custom configuration for medical text
        custom_config = r'--oem 3 --psm 6 -c tessedit_char_whitelist=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-:;/()%'
        text = pytesseract.image_to_string(processed_img, config=custom_config)
        
        return text.strip()
    except Exception as e:
        logger.error(f"Text extraction from image failed: {str(e)}")
        return ""

# ========================
# TEXT PROCESSING FUNCTIONS
# ========================
def extract_medical_entities(text):
    """Extract medical entities from text using regex patterns"""
    results = defaultdict(list)
    text = text.lower()
    
    # Extract medical conditions
    for condition in MEDICAL_TERMS['conditions']:
        if re.search(rf'\b{re.escape(condition)}\b', text):
            results['conditions'].append(condition)
    
    # Extract medications
    for medication in MEDICAL_TERMS['medications']:
        if re.search(rf'\b{re.escape(medication)}\b', text):
            results['medications'].append(medication)
    
    # Extract allergies
    for allergy in MEDICAL_TERMS['allergies']:
        if re.search(rf'\b{re.escape(allergy)}\b', text):
            results['allergies'].append(allergy)
    
    # Extract lab values with numerical values
    lab_patterns = {
        'blood sugar': r'blood sugar[:\s]*(\d+\.?\d*)',
        'glucose': r'glucose[:\s]*(\d+\.?\d*)',
        'hba1c': r'hba1c[:\s]*(\d+\.?\d*)',
        'cholesterol': r'cholesterol[:\s]*(\d+\.?\d*)',
        'hdl': r'hdl[:\s]*(\d+\.?\d*)',
        'ldl': r'ldl[:\s]*(\d+\.?\d*)',
        'blood pressure': r'blood pressure[:\s]*(\d+)\s*/\s*(\d+)',
        'bmi': r'bmi[:\s]*(\d+\.?\d*)'
    }
    
    for test, pattern in lab_patterns.items():
        matches = re.findall(pattern, text)
        if matches:
            results['lab_results'].append({test: matches})
    
    # Extract numerical values with units
    value_pattern = r'(\b\d+\.?\d*\s*(?:mg/dL|mmol/L|mg/L|g/dL|%|mm/Hg|cm|kg|lb|in)\b)'
    value_matches = re.findall(value_pattern, text)
    if value_matches:
        results['numerical_values'] = value_matches
    
    return dict(results)

def analyze_text_semantics(text):
    """Perform basic semantic analysis on medical text"""
    # Simple sentiment analysis for medical context
    positive_indicators = ['normal', 'stable', 'improved', 'better', 'resolved', 'negative']
    negative_indicators = ['abnormal', 'elevated', 'high', 'low', 'positive', 'worse', 'severe']
    
    positive_count = sum(1 for word in positive_indicators if word in text.lower())
    negative_count = sum(1 for word in negative_indicators if word in text.lower())
    
    sentiment = "neutral"
    if positive_count > negative_count:
        sentiment = "positive"
    elif negative_count > positive_count:
        sentiment = "negative"
    
    # Extract dates
    date_pattern = r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b'
    dates = re.findall(date_pattern, text)
    
    return {
        'sentiment': sentiment,
        'positive_indicators': positive_count,
        'negative_indicators': negative_count,
        'dates_found': dates
    }

# ========================
# CSV PROCESSING FUNCTIONS
# ========================
def process_csv_report(csv_path):
    """Process CSV medical reports and extract structured data"""
    try:
        df = pd.read_csv(csv_path)
        results = {}
        
        # Basic statistics
        results['row_count'] = len(df)
        results['column_names'] = list(df.columns)
        results['data_types'] = {col: str(df[col].dtype) for col in df.columns}
        
        # Check for common medical columns
        medical_data = {}
        for col in df.columns:
            col_lower = col.lower()
            
            # Identify numeric columns that might contain lab values
            if df[col].dtype in ['int64', 'float64']:
                medical_data[col] = {
                    'min': float(df[col].min()),
                    'max': float(df[col].max()),
                    'mean': float(df[col].mean()),
                    'std': float(df[col].std())
                }
            
            # Check for specific medical terms in column names
            for category, terms in MEDICAL_TERMS.items():
                for term in terms:
                    if term in col_lower:
                        if category not in medical_data:
                            medical_data[category] = []
                        medical_data[category].append(col)
        
        results['medical_columns'] = medical_data
        
        # Extract potential abnormal values
        abnormal_values = {}
        for col in df.columns:
            if df[col].dtype in ['int64', 'float64']:
                # Simple heuristic for abnormal values (outside 2 standard deviations)
                mean = df[col].mean()
                std = df[col].std()
                abnormal = df[(df[col] < mean - 2*std) | (df[col] > mean + 2*std)]
                if not abnormal.empty:
                    abnormal_values[col] = abnormal[col].tolist()
        
        results['potential_abnormal_values'] = abnormal_values
        
        return results
    except Exception as e:
        logger.error(f"CSV processing failed: {str(e)}")
        return {}

# ========================
# DATASET PROCESSING FUNCTIONS
# ========================
def process_medical_dataset(dataset_path, dataset_type):
    """Process structured medical datasets"""
    results = {}
    
    try:
        # Check if it's a directory with multiple files
        if os.path.isdir(dataset_path):
            csv_files = [f for f in os.listdir(dataset_path) if f.endswith('.csv')]
            image_files = [f for f in os.listdir(dataset_path) if f.endswith(('.png', '.jpg', '.jpeg'))]
            
            results['csv_files'] = csv_files
            results['image_files'] = image_files
            
            # Process CSV files
            for csv_file in csv_files:
                csv_path = os.path.join(dataset_path, csv_file)
                results[csv_file] = process_csv_report(csv_path)
            
            # Process image files
            for image_file in image_files:
                image_path = os.path.join(dataset_path, image_file)
                text = extract_text_from_image(image_path)
                if text:
                    results[image_file] = extract_medical_entities(text)
        
        # Handle single CSV file
        elif dataset_path.endswith('.csv'):
            results = process_csv_report(dataset_path)
        
        return results
    except Exception as e:
        logger.error(f"Dataset processing failed: {str(e)}")
        return {}

# ========================
# EHR INTEGRATION FUNCTIONS
# ========================
def load_ehr_data():
    """Load existing EHR data"""
    if os.path.exists(EHR_FILE):
        try:
            with open(EHR_FILE, 'r') as f:
                return json.load(f)
        except:
            return []
    return []

def update_ehr_with_report(user_id, report_data, report_type):
    """Update EHR with report findings"""
    ehr_data = load_ehr_data()
    
    # Find user in EHR
    user_index = -1
    for i, record in enumerate(ehr_data):
        if record.get('user_id') == user_id:
            user_index = i
            break
    
    # Create new record if user doesn't exist
    if user_index == -1:
        new_record = {
            'user_id': user_id,
            'reports': [],
            'medical_conditions': [],
            'medications': [],
            'allergies': [],
            'lab_results': [],
            'last_updated': datetime.now().isoformat()
        }
        ehr_data.append(new_record)
        user_index = len(ehr_data) - 1
    
    # Add report to user's record
    report_entry = {
        'type': report_type,
        'data': report_data,
        'date_processed': datetime.now().isoformat()
    }
    
    if 'reports' not in ehr_data[user_index]:
        ehr_data[user_index]['reports'] = []
    ehr_data[user_index]['reports'].append(report_entry)
    
    # Update medical conditions
    if 'conditions' in report_data:
        existing_conditions = set(ehr_data[user_index].get('medical_conditions', []))
        new_conditions = set(report_data['conditions'])
        ehr_data[user_index]['medical_conditions'] = list(existing_conditions.union(new_conditions))
    
    # Update medications
    if 'medications' in report_data:
        existing_meds = set(ehr_data[user_index].get('medications', []))
        new_meds = set(report_data['medications'])
        ehr_data[user_index]['medications'] = list(existing_meds.union(new_meds))
    
    # Update allergies
    if 'allergies' in report_data:
        existing_allergies = set(ehr_data[user_index].get('allergies', []))
        new_allergies = set(report_data['allergies'])
        ehr_data[user_index]['allergies'] = list(existing_allergies.union(new_allergies))
    
    # Update lab results
    if 'lab_results' in report_data:
        if 'lab_results' not in ehr_data[user_index]:
            ehr_data[user_index]['lab_results'] = []
        ehr_data[user_index]['lab_results'].extend(report_data['lab_results'])
    
    # Update timestamp
    ehr_data[user_index]['last_updated'] = datetime.now().isoformat()
    
    # Save updated EHR
    with open(EHR_FILE, 'w') as f:
        json.dump(ehr_data, f, indent=2)
    
    return True

# ========================
# MAIN PROCESSING FUNCTION
# ========================
def analyze_reports():
    """Main function to analyze all medical reports"""
    logger.info("Starting medical report analysis")
    
    # Check if report directory exists
    if not os.path.exists(REPORT_DIR):
        logger.error(f"Report directory not found: {REPORT_DIR}")
        return
    
    all_results = {}
    
    # Process each user directory
    for user_dir in os.listdir(REPORT_DIR):
        user_path = os.path.join(REPORT_DIR, user_dir)
        if not os.path.isdir(user_path):
            continue
        
        logger.info(f"Processing reports for user: {user_dir}")
        user_results = {}
        
        # Process individual report files
        for report_file in os.listdir(user_path):
            report_path = os.path.join(user_path, report_file)
            
            # Process image reports
            if report_file.lower().endswith(('.png', '.jpg', '.jpeg')):
                logger.info(f"Processing image report: {report_file}")
                text = extract_text_from_image(report_path)
                if text:
                    entities = extract_medical_entities(text)
                    semantics = analyze_text_semantics(text)
                    user_results[report_file] = {
                        'entities': entities,
                        'semantics': semantics,
                        'text_sample': text[:500] + '...' if len(text) > 500 else text
                    }
            
            # Process CSV reports
            elif report_file.lower().endswith('.csv'):
                logger.info(f"Processing CSV report: {report_file}")
                csv_results = process_csv_report(report_path)
                user_results[report_file] = csv_results
        
        # Process dataset directories
        for dataset_type in ['gretalai', 'Symptom2Disease', 'venetis']:
            dataset_path = os.path.join(user_path, f"{dataset_type}_dataset")
            if os.path.exists(dataset_path):
                logger.info(f"Processing {dataset_type} dataset for user: {user_dir}")
                dataset_results = process_medical_dataset(dataset_path, dataset_type)
                user_results[f"{dataset_type}_dataset"] = dataset_results
        
        # Update EHR with user results
        if user_results:
            update_ehr_with_report(user_dir, user_results, 'medical_reports')
            all_results[user_dir] = user_results
    
    # Save comprehensive results
    results_file = os.path.join(OUTPUT_DIR, f"report_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
    with open(results_file, 'w') as f:
        json.dump(all_results, f, indent=2)
    
    logger.info(f"Report analysis complete. Results saved to: {results_file}")
    
    # Generate summary report
    generate_summary_report(all_results)
    
    return all_results

def generate_summary_report(results):
    """Generate a summary report of the analysis"""
    summary = {
        'total_users': len(results),
        'users_with_findings': 0,
        'total_conditions': 0,
        'total_medications': 0,
        'total_allergies': 0,
        'users_by_condition': defaultdict(int),
        'users_by_medication': defaultdict(int)
    }
    
    for user_id, user_data in results.items():
        has_findings = False
        
        # Check all report types for medical entities
        for report_name, report_data in user_data.items():
            if 'entities' in report_data:
                entities = report_data['entities']
                
                if 'conditions' in entities and entities['conditions']:
                    summary['total_conditions'] += len(entities['conditions'])
                    has_findings = True
                    for condition in entities['conditions']:
                        summary['users_by_condition'][condition] += 1
                
                if 'medications' in entities and entities['medications']:
                    summary['total_medications'] += len(entities['medications'])
                    has_findings = True
                    for medication in entities['medications']:
                        summary['users_by_medication'][medication] += 1
                
                if 'allergies' in entities and entities['allergies']:
                    summary['total_allergies'] += len(entities['allergies'])
                    has_findings = True
        
        if has_findings:
            summary['users_with_findings'] += 1
    
    # Save summary report
    summary_file = os.path.join(OUTPUT_DIR, f"analysis_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    logger.info(f"Summary report generated: {summary_file}")
    
    return summary

# ========================
# VISUALIZATION FUNCTIONS
# ========================
def generate_visualizations(summary):
    """Generate visualizations from the summary data"""
    try:
        # Conditions distribution
        if summary['users_by_condition']:
            conditions = list(summary['users_by_condition'].keys())
            counts = list(summary['users_by_condition'].values())
            
            plt.figure(figsize=(10, 6))
            plt.barh(conditions, counts)
            plt.xlabel('Number of Users')
            plt.title('Medical Conditions Distribution')
            plt.tight_layout()
            plt.savefig(os.path.join(OUTPUT_DIR, 'conditions_distribution.png'))
            plt.close()
        
        # Medications distribution
        if summary['users_by_medication']:
            medications = list(summary['users_by_medication'].keys())
            counts = list(summary['users_by_medication'].values())
            
            plt.figure(figsize=(10, 6))
            plt.barh(medications, counts)
            plt.xlabel('Number of Users')
            plt.title('Medications Distribution')
            plt.tight_layout()
            plt.savefig(os.path.join(OUTPUT_DIR, 'medications_distribution.png'))
            plt.close()
        
        logger.info("Visualizations generated successfully")
    except Exception as e:
        logger.error(f"Visualization generation failed: {str(e)}")

# ========================
# MAIN EXECUTION
# ========================
if __name__ == "__main__":
    print("Starting Medical Report Analyzer...")
    logger.info("==== MEDICAL REPORT ANALYZER STARTED ====")
    
    # Analyze all reports
    results = analyze_reports()
    
    # Generate summary and visualizations
    if results:
        summary = generate_summary_report(results)
        generate_visualizations(summary)
    
    print("Report analysis completed successfully!")
    logger.info("==== MEDICAL REPORT ANALYZER COMPLETED ====")