#D:\nutriplan-ai\ml-engine\scripts\ehr_extractor.py


import os
import re
import json
import cv2
import pandas as pd
import numpy as np
import pytesseract
from PIL import Image
from pathlib import Path
from rich import print
from rich.panel import Panel
from rich.progress import track
from datetime import datetime

# =====================================================================================
# CONFIGURATION
# =====================================================================================
BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DATA_DIR = BASE_DIR / "data"
EHR_OUTPUT_DIR = RAW_DATA_DIR / "ehr"
PATIENT_REPORT_DIR = RAW_DATA_DIR / "patient report"
HANDWRITTEN_DIR = RAW_DATA_DIR / "handwritten"
TXT_EXTENSIONS = ['.txt']
IMG_EXTENSIONS = ['.jpg', '.png', '.jpeg']
CSV_EXTENSIONS = ['.csv']
os.makedirs(EHR_OUTPUT_DIR, exist_ok=True)

# =====================================================================================
# REGEX PATTERNS FOR MEDICAL TERM EXTRACTION
# =====================================================================================
patterns = {
    "diagnosis": re.compile(r"(?i)(diagnosis|diagnosed|condition):?\s*([\w\s,]+)"),
    "medications": re.compile(r"(?i)(medication|medications|drugs):?\s*([\w\s,]+)"),
    "allergies": re.compile(r"(?i)(allergy|allergies):?\s*([\w\s,]+)"),
    "user_id": re.compile(r"(?i)id[:=]?\s*(\d+)")
}

# =====================================================================================
# OCR PROCESSING UTILITIES
# =====================================================================================
def extract_text_from_image(img_path):
    try:
        image = Image.open(img_path)
        return pytesseract.image_to_string(image)
    except Exception as e:
        print(f"[red]OCR Error for {img_path}: {str(e)}[/red]")
        return ""

def extract_from_text(text):
    ehr = {
        "user_id": None,
        "medical_conditions": [],
        "allergies": [],
        "medications": []
    }

    for label, regex in patterns.items():
        match = regex.findall(text)
        if match:
            if label == "user_id":
                ehr["user_id"] = match[0]
            else:
                extracted = [x.strip() for x in match[0][1].split(",") if x.strip()]
                ehr[label if label != "diagnosis" else "medical_conditions"] = extracted
    return ehr

# =====================================================================================
# FILE PARSING FUNCTIONS
# =====================================================================================
def parse_text_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        return f.read()

def parse_csv_file(file_path):
    df = pd.read_csv(file_path)
    ehr_records = []
    for _, row in df.iterrows():
        record = {
            "user_id": str(row.get("user_id", f"csv_{_}")),
            "medical_conditions": [x.strip() for x in str(row.get("diagnosis", "")).split(",") if x],
            "medications": [x.strip() for x in str(row.get("medications", "")).split(",") if x],
            "allergies": [x.strip() for x in str(row.get("allergies", "")).split(",") if x]
        }
        ehr_records.append(record)
    return ehr_records

# =====================================================================================
# MAIN EHR EXTRACTOR FUNCTION
# =====================================================================================
def process_files(directory, file_type):
    ehr_data = []
    files = [f for f in Path(directory).glob("*") if f.suffix.lower() in file_type]

    for file in track(files, description=f"Processing {directory.name}..."):
        if file.suffix in IMG_EXTENSIONS:
            text = extract_text_from_image(file)
            ehr = extract_from_text(text)
            if ehr["user_id"]:
                ehr_data.append(ehr)
        elif file.suffix in TXT_EXTENSIONS:
            text = parse_text_file(file)
            ehr = extract_from_text(text)
            if ehr["user_id"]:
                ehr_data.append(ehr)
        elif file.suffix in CSV_EXTENSIONS:
            ehr_data.extend(parse_csv_file(file))
    return ehr_data

# =====================================================================================
# SAVE OUTPUT
# =====================================================================================
def save_ehr_to_json(ehr_records):
    for record in ehr_records:
        uid = record.get("user_id", f"unknown_{datetime.now().timestamp()}")
        file_path = EHR_OUTPUT_DIR / f"{uid}.json"
        with open(file_path, "w") as f:
            json.dump(record, f, indent=4)
    print(f"[green]✅ Saved {len(ehr_records)} EHR files to {EHR_OUTPUT_DIR}[/green]")

# =====================================================================================
# MAIN ENTRY POINT
# =====================================================================================
def main():
    print(Panel.fit("🧠 [bold magenta]EHR Extractor - NutriPlan AI[/]", border_style="magenta"))

    all_records = []

    # Process: Handwritten (OCR)
    if HANDWRITTEN_DIR.exists():
        records = process_files(HANDWRITTEN_DIR, IMG_EXTENSIONS)
        all_records.extend(records)
        print(f"[cyan]📝 Handwritten OCR Extracted: {len(records)}[/cyan]")

    # Process: Patient Reports (CSV + PNG)
    if PATIENT_REPORT_DIR.exists():
        records_txt = process_files(PATIENT_REPORT_DIR, TXT_EXTENSIONS)
        records_csv = process_files(PATIENT_REPORT_DIR, CSV_EXTENSIONS)
        all_records.extend(records_txt)
        all_records.extend(records_csv)
        print(f"[cyan]📑 Structured Reports Extracted: {len(records_txt) + len(records_csv)}[/cyan]")

    # Save
    if all_records:
        save_ehr_to_json(all_records)
    else:
        print("[yellow]⚠ No records extracted.[/yellow]")

if __name__ == "__main__":
    main()
