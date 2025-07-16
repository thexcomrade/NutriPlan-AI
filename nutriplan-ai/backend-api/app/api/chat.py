# File: app/api/chat.py

from fastapi import APIRouter, HTTPException, status, Depends, Request
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from uuid import uuid4

from app.services.chat_service import ChatService
from app.models.chat_model import ChatMessage, ChatResponse
from app.services.auth_service import get_current_user
from app.models.user_model import UserInDB

router = APIRouter(prefix="/chat", tags=["AI Dietician Chat 💬"])

# 🌿 Emojis for themes, reactions, and content flavors
EMOJI_MAP: Dict[str, str] = {
    "greeting": "🌿",
    "diet": "🥗",
    "warning": "⚠️",
    "info": "ℹ️",
    "success": "✅",
    "error": "❌",
    "fun": "😄",
    "energy": "⚡",
    "hydration": "💧",
    "eco": "🌎",
    "fruit": "🍎",
    "veggie": "🥦",
    "protein": "🍗",
    "grain": "🍞",
    "focus": "🧠",
    "balance": "🧘",
    "water": "🚰",
    "motivation": "🔥"
}

# 🎭 Avatars matching themes/moods
AVATAR_MAP: Dict[str, str] = {
    "eco": "🌱",
    "fruit": "🍓",
    "fun": "🐥",
    "energy": "🐝",
    "hydration": "🦦",
    "protein": "🐮",
    "focus": "🧠",
    "balance": "🧘",
    "grain": "🐿️",
    "motivation": "🐲",
    "info": "💡",
    "default": "🤖"
}

# 📩 Input from the user
class ChatRequest(BaseModel):
    message: str = Field(..., description="User's question or input to the AI Dietician")
    context: Optional[Dict[str, Any]] = Field(default_factory=dict)
    mood: Optional[str] = Field(default="eco", description="Theme/mood for styled reply")

# 📤 Chatbot reply model
class ChatReply(BaseModel):
    reply_id: str
    reply_text: str
    styled_response: str
    timestamp: str
    eco_theme: Optional[bool] = True
    mood: Optional[str] = "eco"
    animation: Optional[str] = None
    avatar: Optional[str] = None

# 🎨 Emoji-enhanced and Markdown-formatted reply
def style_response(text: str, mood: str = "eco") -> str:
    emoji = EMOJI_MAP.get(mood, EMOJI_MAP["eco"])
    return f"{emoji} **{text.strip().capitalize()}** {emoji}"

# 👤 Avatar fetcher
def get_avatar(mood: str) -> str:
    return AVATAR_MAP.get(mood, AVATAR_MAP["default"])

# 🗨️ Get previous chat history — FUTURE: DB Integration
@router.get("/history", response_model=List[ChatReply])
async def get_chat_history(current_user: UserInDB = Depends(get_current_user)):
    # TODO: Fetch from DB using current_user.email
    return []

# 🚀 Main chat interaction endpoint
@router.post("/message", response_model=ChatReply)
async def send_message(
    chat_request: ChatRequest,
    current_user: UserInDB = Depends(get_current_user)
):
    if not chat_request.message.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message cannot be empty"
        )

    try:
        # ⛽ Generate AI reply via ChatService
        reply_text = ChatService.generate_reply(
            message=chat_request.message,
            context=chat_request.context,
            user_email=current_user.email
        )

        styled = style_response(reply_text, chat_request.mood)
        avatar = get_avatar(chat_request.mood)

        return ChatReply(
            reply_id=str(uuid4()),
            reply_text=reply_text,
            styled_response=styled,
            timestamp=datetime.utcnow().isoformat(),
            mood=chat_request.mood,
            animation="fadeInUp",
            avatar=avatar,
            eco_theme=True
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Chatbot error: {str(e)}"
        )

# 🎭 Get all supported emojis
@router.get("/emojis", response_model=Dict[str, str])
async def get_available_emojis():
    return EMOJI_MAP

# 🤖 Help Guide Endpoint
@router.get("/help", response_model=ChatReply)
async def get_help_message():
    help_text = (
        "👋 Here's what you can ask me:\n"
        "- Affordable high-protein hostel diet\n"
        "- Post-workout recovery meals\n"
        "- Quick healthy snacks\n"
        "- Water intake reminders\n"
        "- Budget gym meals\n\n"
        "Let's build a healthier, eco-friendly you! 🌱"
    )
    return ChatReply(
        reply_id=str(uuid4()),
        reply_text=help_text,
        styled_response=style_response(help_text, "info"),
        timestamp=datetime.utcnow().isoformat(),
        mood="info",
        animation="bounceInLeft",
        avatar=get_avatar("info"),
        eco_theme=True
    )

# 🤖 About the NutriBot Assistant
@router.get("/about", response_model=ChatReply)
async def about_bot():
    intro = (
        "Hi, I'm **NutriBot** 🤖 — your eco-friendly AI dietician assistant.\n\n"
        "I specialize in:\n"
        "- Personalized hostel/gym diets\n"
        "- Affordable meal planning\n"
        "- Nutrition coaching\n"
        "- Hydration & mental wellness tips\n\n"
        "I'm always here to guide you 🌿"
    )
    return ChatReply(
        reply_id=str(uuid4()),
        reply_text=intro,
        styled_response=style_response(intro, "fun"),
        timestamp=datetime.utcnow().isoformat(),
        mood="fun",
        animation="slideInRight",
        avatar="🌽",
        eco_theme=True
    )

# 🎨 Mood setter API — optional personalization feature
class MoodRequest(BaseModel):
    mood: str = Field(..., description="Select a mood or theme (eco, fruit, focus, etc.)")

@router.post("/set-mood", status_code=status.HTTP_200_OK)
async def set_mood(mood_request: MoodRequest):
    mood = mood_request.mood.lower()
    if mood not in EMOJI_MAP:
        raise HTTPException(
            status_code=400,
            detail="Unsupported mood. Available moods: " + ", ".join(EMOJI_MAP.keys())
        )
    return {
        "message": f"🎨 Mood set to '{mood}' successfully.",
        "avatar": get_avatar(mood),
        "emoji": EMOJI_MAP[mood]
    }

# 🛠 Healthcheck API for service monitoring
@router.get("/ping", status_code=200)
async def ping_bot():
    return {
        "status": "ok",
        "message": "NutriPlan AI chatbot is alive and healthy 🌟",
        "emoji": EMOJI_MAP["success"]
    }

# -------------------------------------------
# 📌 Future Improvements & Expansion
# -------------------------------------------
"""
✅ Save chat history by user email (MongoDB/PostgreSQL)
✅ Enable WebSocket streaming for real-time chat
✅ Sentiment analysis + response adaptation
✅ Themed personalities (eco, gym, mental wellness, hostel life)
✅ Image-to-diet recommendation (ML-based food scanner)
✅ Voice input command (Speech-to-Text)
✅ Health data ingestion from wearables
✅ Regional language support (Malayalam, Hindi, Tamil)
✅ Chat animations with Lottie
✅ Auto PDF export of meal plans
✅ Admin dashboard for user insights and trends
✅ Firebase integration for notification triggers
✅ GPT fine-tuning for hyper-personalization
"""

