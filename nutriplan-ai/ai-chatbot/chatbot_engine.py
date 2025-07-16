# D:\nutriplan-ai\ai-chatbot\chatbot_engine.py

import os
import json
import yaml
import random
import re
import uuid
import time
from datetime import datetime, timedelta
from typing import Dict, Optional

# Language Detection and Translation
from langdetect import detect
from googletrans import Translator

# Optional: OpenAI integration
try:
    import openai
    openai.api_key = os.getenv("OPENAI_API_KEY")
except ImportError:
    openai = None

# === Constants ===
INTENTS_DIR = os.path.join(os.path.dirname(__file__), "intents")
LOG_FILE = os.path.join(os.path.dirname(__file__), "chat_logs.json")
MEMORY_TTL_SECONDS = 600  # 10 minutes

translator = Translator()

# === Load Intents ===
def load_intents() -> Dict[str, dict]:
    intents = {}
    for filename in os.listdir(INTENTS_DIR):
        if filename.endswith(".yml"):
            path = os.path.join(INTENTS_DIR, filename)
            with open(path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
                intents.update(data)
    return intents

INTENTS = load_intents()

# === Preprocessing ===
def clean_text(text: str) -> str:
    return re.sub(r"[^\w\s]", "", text.lower().strip())

# === Intent Detection ===
def detect_intent(user_input: str) -> Optional[str]:
    cleaned = clean_text(user_input)
    for intent, data in INTENTS.items():
        for pattern in data.get("patterns", []):
            if re.search(pattern.lower(), cleaned):
                return intent
    return None

def get_response(intent: str) -> str:
    responses = INTENTS.get(intent, {}).get("responses", [])
    return random.choice(responses) if responses else "I'm not sure how to respond to that."

# === Context Memory with TTL ===
class ContextMemory:
    def __init__(self):
        self.memory = {}

    def set_context(self, user_id: str, intent: str):
        self.memory[user_id] = {
            "intent": intent,
            "timestamp": datetime.now()
        }

    def get_context(self, user_id: str) -> Optional[str]:
        ctx = self.memory.get(user_id)
        if not ctx:
            return None
        if datetime.now() - ctx["timestamp"] > timedelta(seconds=MEMORY_TTL_SECONDS):
            del self.memory[user_id]
            return None
        return ctx["intent"]

    def clear_context(self, user_id: str):
        if user_id in self.memory:
            del self.memory[user_id]

context_memory = ContextMemory()

# === Conversation Logger ===
def log_conversation(user_id: str, user_input: str, response: str, intent: Optional[str]):
    entry = {
        "id": str(uuid.uuid4()),
        "timestamp": datetime.utcnow().isoformat(),
        "user_id": user_id,
        "input": user_input,
        "response": response,
        "intent": intent
    }
    try:
        if not os.path.exists(LOG_FILE):
            with open(LOG_FILE, "w", encoding="utf-8") as f:
                json.dump([entry], f, indent=2)
        else:
            with open(LOG_FILE, "r+", encoding="utf-8") as f:
                data = json.load(f)
                data.append(entry)
                f.seek(0)
                json.dump(data, f, indent=2)
    except Exception as e:
        print(f"Logging error: {e}")

# === Translation & Language Detection ===
def detect_and_translate_to_english(text: str) -> str:
    try:
        lang = detect(text)
        if lang != "en":
            translated = translator.translate(text, dest="en")
            return translated.text
    except Exception as e:
        print(f"Translation error: {e}")
    return text

# === Main Chat Handler ===
def process_user_input(user_input: str, user_id: str = "default_user") -> str:
    original_input = user_input
    user_input = detect_and_translate_to_english(user_input)
    intent = detect_intent(user_input)

    if intent:
        context_memory.set_context(user_id, intent)
        response = get_response(intent)
        log_conversation(user_id, original_input, response, intent)
        return response

    if openai:
        try:
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a helpful dietician chatbot."},
                    {"role": "user", "content": user_input}
                ],
                temperature=0.7,
                max_tokens=150
            )
            reply = response["choices"][0]["message"]["content"].strip()
            log_conversation(user_id, original_input, reply, None)
            return reply
        except Exception as e:
            return f"OpenAI error: {str(e)}"

    fallback = "I'm sorry, I couldn't understand that. Please rephrase."
    log_conversation(user_id, original_input, fallback, None)
    return fallback

# === API-compatible Handler ===
def chat_api_handler(event: dict) -> dict:
    user_input = event.get("message", "")
    user_id = event.get("user_id", "guest")
    response = process_user_input(user_input, user_id)
    return {
        "reply": response,
        "intent": context_memory.get_context(user_id)
    }

# === Voice Input Handler (for mobile integration stub) ===
def voice_input_handler(audio_data: bytes) -> str:
    """
    Placeholder: Converts voice input to text.
    You can integrate Whisper, Google Speech-to-Text, or Vosk here.
    """
    return "Voice input not implemented yet. Use text input."

# === CLI Mode ===
if __name__ == "__main__":
    print(\"\"\"\nNutriPlan AI Chatbot CLI
Type 'exit' to quit.
Supports multilingual input, OpenAI fallback, and context memory.\n\"\"\")
    user_id = "cli_user"
    while True:
        user_input = input("You: ")
        if user_input.lower() in ("exit", "quit"):
            break
        response = process_user_input(user_input, user_id)
        print("Bot:", response)
