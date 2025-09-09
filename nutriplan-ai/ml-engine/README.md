\\Core ML module for personalized meal recommendations and medical safety checks.

Directory Structure
ml-engine/
├── data/                 # Datasets and EHR data
├── models/               # Trained ML models
├── scripts/              # Processing and training scripts
└── README.md

Quick Start

1. Install requirements:
  pip install -r requirements.txt
2. Run processing scripts:
  python scripts/ocr_extractor.py
  python scripts/report_analyzer.py  
  python scripts/voice_parser.py
3. Models will generate in models/ directory
4. Processed data stored in data/ehr/unified_ehr.json

Requirements
Python 3.8+
See requirements.txt for full dependencies

Output
Processed EHR data in structured JSON format
Trained ML models for recommendations and safety checks
Integrated with main NutriPlan AI application