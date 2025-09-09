import os
import json
import re
import wave
import contextlib
import speech_recognition as sr
from pydub import AudioSegment
import numpy as np
from collections import defaultdict
import logging
from datetime import datetime
from langdetect import detect, LangDetectException
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import warnings
warnings.filterwarnings('ignore')

# ========================
# CONFIGURATION
# ========================
BASE_DIR = r"D:\nutriplan-ai\ml-engine"
DATA_DIR = os.path.join(BASE_DIR, "data")
VOICE_DIR = os.path.join(DATA_DIR, "voice dataset")
EHR_DIR = os.path.join(DATA_DIR, "ehr")
EHR_FILE = os.path.join(EHR_DIR, "unified_ehr.json")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
LOG_DIR = os.path.join(BASE_DIR, "logs")

# Create necessary directories
for directory in [OUTPUT_DIR, LOG_DIR, EHR_DIR]:
    os.makedirs(directory, exist_ok=True)

# ========================
# LOGGING CONFIGURATION
# ========================
logging.basicConfig(
    filename=os.path.join(LOG_DIR, 'voice_parser.log'),
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='a'
)
logger = logging.getLogger('VoiceParser')

# ========================
# MEDICAL & NUTRITION KNOWLEDGE BASE
# ========================
MEDICAL_TERMS = {
    'conditions': [
        'diabetes', 'hypertension', 'hyperlipidemia', 'asthma', 'arthritis',
        'osteoporosis', 'depression', 'anxiety', 'hypothyroidism', 'anemia',
        'migraine', 'copd', 'heart disease', 'kidney disease', 'cancer',
        'obesity', 'coronary artery disease', 'myocardial infarction'
    ],
    'medications': [
        'metformin', 'amlodipine', 'lisinopril', 'atorvastatin', 'albuterol',
        'levothyroxine', 'sertraline', 'insulin', 'losartan', 'omeprazole',
        'aspirin', 'ibuprofen', 'acetaminophen', 'warfarin', 'prednisone'
    ],
    'allergies': [
        'penicillin', 'peanuts', 'shellfish', 'eggs', 'soy', 'dairy', 'gluten',
        'sulfa', 'aspirin', 'latex', 'pollen', 'dust mites', 'pet dander'
    ]
}

NUTRITION_TERMS = {
    'food_items': [
        'rice', 'wheat', 'oats', 'bread', 'pasta', 'noodles', 'potato', 'sweet potato',
        'chicken', 'fish', 'beef', 'pork', 'eggs', 'milk', 'cheese', 'yogurt',
        'apple', 'banana', 'orange', 'mango', 'grape', 'strawberry', 'blueberry',
        'carrot', 'broccoli', 'spinach', 'tomato', 'onion', 'garlic', 'ginger',
        'water', 'tea', 'coffee', 'juice', 'smoothie', 'protein shake'
    ],
    'diet_types': [
        'vegetarian', 'vegan', 'keto', 'paleo', 'mediterranean', 'low carb',
        'low fat', 'gluten free', 'dairy free', 'diabetic', 'high protein'
    ],
    'meal_types': [
        'breakfast', 'lunch', 'dinner', 'snack', 'dessert', 'appetizer'
    ]
}

COMMAND_PATTERNS = {
    'show_meal_plan': [
        r'show my meal plan',
        r'what should I eat',
        r'meal suggestions',
        r'recommend meals',
        r'food plan'
    ],
    'update_allergy': [
        r'update my allergy',
        r'add allergy',
        r'I\'m allergic to',
        r'allergic to',
        r'remove allergy'
    ],
    'update_condition': [
        r'update my condition',
        r'I have',
        r'diagnosed with',
        r'suffering from',
        r'medical condition'
    ],
    'update_medication': [
        r'update my medication',
        r'taking',
        r'prescribed',
        r'medicine',
        r'medication'
    ],
    'update_preference': [
        r'update my preference',
        r'don\'t like',
        r'prefer not to eat',
        r'avoid',
        r'like to eat'
    ]
}

# ========================
# AUDIO PROCESSING FUNCTIONS
# ========================
def convert_dat_to_wav(dat_path, wav_path):
    """Convert .dat files to .wav format for processing"""
    try:
        # Read .dat file as raw PCM data
        with open(dat_path, 'rb') as dat_file:
            raw_data = dat_file.read()
        
        # Create WAV file
        with wave.open(wav_path, 'wb') as wav_file:
            wav_file.setnchannels(1)  # mono
            wav_file.setsampwidth(2)  # 2 bytes per sample
            wav_file.setframerate(16000)  # 16kHz sample rate
            wav_file.writeframes(raw_data)
        
        return True
    except Exception as e:
        logger.error(f"Error converting {dat_path} to WAV: {str(e)}")
        return False

def preprocess_audio(audio_path):
    """Preprocess audio to improve speech recognition accuracy"""
    try:
        # Handle different audio formats
        if audio_path.endswith('.dat'):
            wav_path = audio_path.replace('.dat', '.wav')
            if convert_dat_to_wav(audio_path, wav_path):
                audio_path = wav_path
            else:
                return None
        
        # Load audio file
        audio = AudioSegment.from_file(audio_path)
        
        # Normalize volume
        audio = audio.normalize()
        
        # Apply noise reduction
        audio = audio.low_pass_filter(3000)
        
        # Increase volume if too quiet
        if audio.dBFS < -20:
            audio = audio + 10  # Increase by 10 dB
        
        # Export processed audio
        processed_path = audio_path.replace('.wav', '_processed.wav')
        audio.export(processed_path, format='wav')
        
        return processed_path
    except Exception as e:
        logger.error(f"Audio preprocessing failed: {str(e)}")
        return None

# ========================
# SPEECH-TO-TEXT FUNCTIONS
# ========================
def speech_to_text(audio_path, language='en'):
    """Convert speech to text using multiple engines with fallback"""
    text_results = []
    confidence_scores = []
    
    try:
        # Preprocess audio
        processed_path = preprocess_audio(audio_path)
        if processed_path:
            audio_path = processed_path
        
        # Initialize recognizer
        r = sr.Recognizer()
        
        # Method 1: Google Speech Recognition (primary)
        try:
            with sr.AudioFile(audio_path) as source:
                audio = r.record(source)
                text = r.recognize_google(audio, language=language)
                text_results.append(text)
                confidence_scores.append(0.9)  # Google typically has high confidence
                logger.info(f"Google Speech Recognition: {text}")
        except Exception as e:
            logger.warning(f"Google Speech Recognition failed: {str(e)}")
        
        # Method 2: Sphinx (offline fallback)
        try:
            with sr.AudioFile(audio_path) as source:
                audio = r.record(source)
                text = r.recognize_sphinx(audio)
                text_results.append(text)
                confidence_scores.append(0.6)  # Sphinx typically has lower confidence
                logger.info(f"Sphinx Recognition: {text}")
        except Exception as e:
            logger.warning(f"Sphinx Recognition failed: {str(e)}")
        
        # Select the best result based on confidence
        if text_results:
            best_index = confidence_scores.index(max(confidence_scores))
            return text_results[best_index], confidence_scores[best_index]
        else:
            return "", 0.0
            
    except Exception as e:
        logger.error(f"Speech-to-text conversion failed: {str(e)}")
        return "", 0.0

def detect_language(text):
    """Detect language of the text"""
    try:
        return detect(text)
    except LangDetectException:
        return "en"  # Default to English if detection fails

# ========================
# TEXT PROCESSING FUNCTIONS
# ========================
def remove_noise(text):
    """Clean and normalize text"""
    # Convert to lowercase
    text = text.lower()
    
    # Remove special characters but keep basic punctuation
    text = re.sub(r'[^\w\s.,!?]', '', text)
    
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

def extract_medical_entities(text):
    """Extract medical entities from text"""
    entities = defaultdict(list)
    text = text.lower()
    
    # Extract medical conditions
    for condition in MEDICAL_TERMS['conditions']:
        if re.search(rf'\b{re.escape(condition)}\b', text):
            entities['conditions'].append(condition)
    
    # Extract medications
    for medication in MEDICAL_TERMS['medications']:
        if re.search(rf'\b{re.escape(medication)}\b', text):
            entities['medications'].append(medication)
    
    # Extract allergies
    for allergy in MEDICAL_TERMS['allergies']:
        if re.search(rf'\b{re.escape(allergy)}\b', text):
            entities['allergies'].append(allergy)
    
    return dict(entities)

def extract_nutrition_entities(text):
    """Extract nutrition-related entities from text"""
    entities = defaultdict(list)
    text = text.lower()
    
    # Extract food items
    for food in NUTRITION_TERMS['food_items']:
        if re.search(rf'\b{re.escape(food)}\b', text):
            entities['food_items'].append(food)
    
    # Extract diet types
    for diet in NUTRITION_TERMS['diet_types']:
        if re.search(rf'\b{re.escape(diet)}\b', text):
            entities['diet_types'].append(diet)
    
    # Extract meal types
    for meal in NUTRITION_TERMS['meal_types']:
        if re.search(rf'\b{re.escape(meal)}\b', text):
            entities['meal_types'].append(meal)
    
    # Extract preferences (like/dislike)
    like_pattern = r'(?:like|love|enjoy|want|prefer).*?\b(' + '|'.join(NUTRITION_TERMS['food_items']) + r')\b'
    dislike_pattern = r'(?:dislike|hate|avoid|don\'t like|can\'t eat).*?\b(' + '|'.join(NUTRITION_TERMS['food_items']) + r')\b'
    
    for match in re.finditer(like_pattern, text):
        entities['preferences']['likes'].append(match.group(1))
    
    for match in re.finditer(dislike_pattern, text):
        entities['preferences']['dislikes'].append(match.group(1))
    
    return dict(entities)

def parse_voice_command(text):
    """Parse voice commands and extract intent"""
    text = text.lower()
    
    for command_type, patterns in COMMAND_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, text):
                return command_type
    
    return "unknown"

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

def update_ehr_with_voice_data(user_id, text, entities, command, confidence):
    """Update EHR with voice data"""
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
            'voice_inputs': [],
            'medical_conditions': [],
            'medications': [],
            'allergies': [],
            'dietary_preferences': {
                'likes': [],
                'dislikes': [],
                'restrictions': []
            },
            'last_updated': datetime.now().isoformat()
        }
        ehr_data.append(new_record)
        user_index = len(ehr_data) - 1
    
    # Add voice input to user's record
    voice_entry = {
        'text': text,
        'entities': entities,
        'command': command,
        'confidence': confidence,
        'timestamp': datetime.now().isoformat()
    }
    
    if 'voice_inputs' not in ehr_data[user_index]:
        ehr_data[user_index]['voice_inputs'] = []
    ehr_data[user_index]['voice_inputs'].append(voice_entry)
    
    # Update medical conditions
    if 'conditions' in entities:
        existing_conditions = set(ehr_data[user_index].get('medical_conditions', []))
        new_conditions = set(entities['conditions'])
        ehr_data[user_index]['medical_conditions'] = list(existing_conditions.union(new_conditions))
    
    # Update medications
    if 'medications' in entities:
        existing_meds = set(ehr_data[user_index].get('medications', []))
        new_meds = set(entities['medications'])
        ehr_data[user_index]['medications'] = list(existing_meds.union(new_meds))
    
    # Update allergies
    if 'allergies' in entities:
        existing_allergies = set(ehr_data[user_index].get('allergies', []))
        new_allergies = set(entities['allergies'])
        ehr_data[user_index]['allergies'] = list(existing_allergies.union(new_allergies))
    
    # Update dietary preferences
    if 'preferences' in entities:
        if 'dietary_preferences' not in ehr_data[user_index]:
            ehr_data[user_index]['dietary_preferences'] = {
                'likes': [],
                'dislikes': [],
                'restrictions': []
            }
        
        # Update likes
        if 'likes' in entities['preferences']:
            existing_likes = set(ehr_data[user_index]['dietary_preferences'].get('likes', []))
            new_likes = set(entities['preferences']['likes'])
            ehr_data[user_index]['dietary_preferences']['likes'] = list(existing_likes.union(new_likes))
        
        # Update dislikes
        if 'dislikes' in entities['preferences']:
            existing_dislikes = set(ehr_data[user_index]['dietary_preferences'].get('dislikes', []))
            new_dislikes = set(entities['preferences']['dislikes'])
            ehr_data[user_index]['dietary_preferences']['dislikes'] = list(existing_dislikes.union(new_dislikes))
    
    # Update timestamp
    ehr_data[user_index]['last_updated'] = datetime.now().isoformat()
    
    # Save updated EHR
    with open(EHR_FILE, 'w') as f:
        json.dump(ehr_data, f, indent=2)
    
    return True

# ========================
# VOICE PROCESSING PIPELINE
# ========================
def process_voice_file(user_id, audio_path):
    """Process a single voice file through the complete pipeline"""
    try:
        logger.info(f"Processing voice file: {audio_path}")
        
        # Step 1: Convert speech to text
        text, confidence = speech_to_text(audio_path)
        
        if not text or confidence < 0.5:
            logger.warning(f"Low confidence ({confidence}) or empty result for {audio_path}")
            return None
        
        # Step 2: Clean and normalize text
        clean_text = remove_noise(text)
        
        # Step 3: Detect language
        language = detect_language(clean_text)
        
        # Step 4: Extract medical entities
        medical_entities = extract_medical_entities(clean_text)
        
        # Step 5: Extract nutrition entities
        nutrition_entities = extract_nutrition_entities(clean_text)
        
        # Step 6: Parse voice command
        command = parse_voice_command(clean_text)
        
        # Step 7: Combine all entities
        all_entities = {
            'medical': medical_entities,
            'nutrition': nutrition_entities,
            'language': language
        }
        
        # Step 8: Update EHR
        update_ehr_with_voice_data(user_id, clean_text, all_entities, command, confidence)
        
        # Step 9: Return results
        results = {
            'user_id': user_id,
            'original_text': text,
            'clean_text': clean_text,
            'language': language,
            'entities': all_entities,
            'command': command,
            'confidence': confidence,
            'timestamp': datetime.now().isoformat()
        }
        
        logger.info(f"Successfully processed voice file: {audio_path}")
        return results
        
    except Exception as e:
        logger.error(f"Error processing voice file {audio_path}: {str(e)}")
        return None

def batch_process_voice_files():
    """Process all voice files in the voice dataset directory"""
    logger.info("Starting batch processing of voice files")
    
    # Check if voice directory exists
    if not os.path.exists(VOICE_DIR):
        logger.error(f"Voice directory not found: {VOICE_DIR}")
        return []
    
    all_results = []
    
    # Process each user directory
    for user_dir in os.listdir(VOICE_DIR):
        user_path = os.path.join(VOICE_DIR, user_dir)
        if not os.path.isdir(user_path):
            continue
        
        logger.info(f"Processing voice files for user: {user_dir}")
        
        # Process all audio files in user directory
        for audio_file in os.listdir(user_path):
            audio_path = os.path.join(user_path, audio_file)
            
            # Skip non-audio files
            if not audio_file.lower().endswith(('.wav', '.mp3', '.dat')):
                continue
            
            # Process the audio file
            result = process_voice_file(user_dir, audio_path)
            if result:
                all_results.append(result)
    
    # Save comprehensive results
    if all_results:
        results_file = os.path.join(OUTPUT_DIR, f"voice_processing_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
        with open(results_file, 'w') as f:
            json.dump(all_results, f, indent=2)
        
        logger.info(f"Voice processing complete. Results saved to: {results_file}")
    
    return all_results

# ========================
# COMMAND HANDLING FUNCTIONS
# ========================
def handle_voice_command(user_id, command, entities):
    """Handle voice commands and return appropriate response"""
    response = {
        'user_id': user_id,
        'command': command,
        'response': '',
        'action_required': False
    }
    
    if command == 'show_meal_plan':
        # Generate meal plan based on user preferences and restrictions
        response['response'] = "Here's your personalized meal plan based on your preferences and health conditions."
        response['action_required'] = True
        
    elif command == 'update_allergy':
        # Update allergies in EHR
        allergies = entities['medical'].get('allergies', [])
        response['response'] = f"Your allergy list has been updated. Added allergies: {', '.join(allergies)}"
        
    elif command == 'update_condition':
        # Update medical conditions in EHR
        conditions = entities['medical'].get('conditions', [])
        response['response'] = f"Your medical conditions have been updated. Added conditions: {', '.join(conditions)}"
        
    elif command == 'update_medication':
        # Update medications in EHR
        medications = entities['medical'].get('medications', [])
        response['response'] = f"Your medication list has been updated. Added medications: {', '.join(medications)}"
        
    elif command == 'update_preference':
        # Update dietary preferences in EHR
        likes = entities['nutrition'].get('preferences', {}).get('likes', [])
        dislikes = entities['nutrition'].get('preferences', {}).get('dislikes', [])
        response['response'] = f"Your dietary preferences have been updated. Likes: {', '.join(likes)}. Dislikes: {', '.join(dislikes)}"
        
    else:
        response['response'] = "I didn't understand that command. Please try again."
    
    return response

# ========================
# MAIN EXECUTION
# ========================
if __name__ == "__main__":
    print("Starting Voice Parser for NutriPlan AI...")
    logger.info("==== VOICE PARSER STARTED ====")
    
    # Process all voice files
    results = batch_process_voice_files()
    
    # Handle any commands found
    for result in results:
        if result['command'] != 'unknown':
            response = handle_voice_command(
                result['user_id'], 
                result['command'], 
                result['entities']
            )
            logger.info(f"Command handled: {response}")
    
    print("Voice processing completed successfully!")
    logger.info("==== VOICE PARSER COMPLETED ====")