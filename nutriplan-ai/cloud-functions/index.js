const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const compression = require("compression");
const admin = require("firebase-admin");
const rateLimit = require("express-rate-limit");
const { v4: uuidv4 } = require("uuid");

const app = express();
const PORT = process.env.PORT || 8080;

// Firebase Admin Setup
admin.initializeApp();
const db = admin.firestore();

// Middleware Setup
app.use(cors({ origin: true }));
app.use(helmet());
app.use(compression());
app.use(morgan("combined"));
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true }));

// Rate Limiter
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  message: { error: "Too many requests, please try again later." },
});
app.use(limiter);

/**
 * 🌟 Future Enhancements Planned:
 * 
 * 1. AI Chatbot Endpoint (`/chatAI`)
 *    - Natural conversation support for nutrition queries
 *    - Multilingual (via Google Translate API)
 *    - Sentiment-aware tone matching
 * 
 * 2. Feedback Endpoint (`/submitFeedback`)
 *    - Store user suggestions, complaints, testimonials
 *    - Real-time sentiment analysis
 *    - Generate auto-replies (AI powered)
 * 
 * 3. Analytics Logging (`/logAnalytics`)
 *    - Usage tracking (screen visits, goal trends)
 *    - Heatmaps of food preferences
 *    - Anonymous behavior modeling for app optimization
 * 
 * 4. Smart Diet Advisor (Upcoming)
 *    - Forecast future health trajectory
 *    - Provide gamified goal nudges and daily reminders
 */

// Health Check
app.get("/", (req, res) => {
  res.status(200).json({
    status: "NutriPlan AI Backend Active",
    timestamp: new Date().toISOString(),
  });
});

// ========== Utility Validators ==========
const validateEmail = (email) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

const validateString = (str, min = 2, max = 50) =>
  typeof str === "string" && str.trim().length >= min && str.trim().length <= max;

const validateGender = (g) => ["male", "female", "other"].includes(g.toLowerCase());

const validateGoal = (goal) =>
  ["weight loss", "weight gain", "maintain"].includes(goal.toLowerCase());

const validateActivity = (activity) =>
  ["sedentary", "light", "moderate", "active", "very active"].includes(activity.toLowerCase());

// ========== Routes ==========

/**
 * POST /registerUser
 * Creates a new user document in Firestore
 */
app.post("/registerUser", async (req, res) => {
  try {
    const { name, email, age, gender } = req.body;

    if (!validateEmail(email) || !validateString(name) || !validateGender(gender)) {
      return res.status(400).json({ error: "Invalid user data" });
    }

    const uid = uuidv4();
    await db.collection("users").doc(uid).set({
      name,
      email,
      age: parseInt(age),
      gender,
      preferences: {},
      createdAt: new Date().toISOString(),
    });

    return res.status(201).json({ message: "User registered", userId: uid });
  } catch (err) {
    console.error("Register Error:", err.message);
    return res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /submitPreferences
 * Saves user dietary preferences
 */
app.post("/submitPreferences", async (req, res) => {
  try {
    const { userId, preferences } = req.body;

    if (!userId || !preferences || typeof preferences !== "object") {
      return res.status(400).json({ error: "Invalid input data" });
    }

    await db.collection("users").doc(userId).update({
      preferences,
      updatedAt: new Date().toISOString(),
    });

    return res.status(200).json({ message: "Preferences saved" });
  } catch (err) {
    console.error("Preference Error:", err.message);
    return res.status(500).json({ error: "Could not update preferences" });
  }
});

/**
 * GET /getMealPlan/:userId
 * Fetch user-specific meal plan
 */
app.get("/getMealPlan/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const doc = await db.collection("meal_plans").doc(userId).get();

    if (!doc.exists) return res.status(404).json({ error: "Meal plan not found" });

    return res.status(200).json({ mealPlan: doc.data() });
  } catch (err) {
    console.error("Meal Plan Fetch Error:", err.message);
    return res.status(500).json({ error: "Failed to fetch meal plan" });
  }
});

/**
 * POST /chatAI [Future]
 * Placeholder route for future AI chatbot
 */
app.post("/chatAI", async (req, res) => {
  return res.status(501).json({
    message: "🤖 Chatbot under construction. Coming soon!",
    supportedLanguages: ["en", "ml", "hi", "ta", "te"],
  });
});

/**
 * POST /submitFeedback [Future]
 * Collects user feedback for analysis
 */
app.post("/submitFeedback", async (req, res) => {
  try {
    const { userId, message, sentiment } = req.body;

    if (!userId || !validateString(message)) {
      return res.status(400).json({ error: "Invalid feedback" });
    }

    await db.collection("feedback").add({
      userId,
      message,
      sentiment: sentiment || "neutral",
      receivedAt: new Date().toISOString(),
    });

    return res.status(200).json({ message: "Feedback received, thank you!" });
  } catch (err) {
    console.error("Feedback Error:", err.message);
    return res.status(500).json({ error: "Failed to submit feedback" });
  }
});

/**
 * POST /logAnalytics [Future]
 * Logs app usage for optimization
 */
app.post("/logAnalytics", async (req, res) => {
  try {
    const { event, metadata = {} } = req.body;

    if (!validateString(event)) {
      return res.status(400).json({ error: "Invalid analytics event" });
    }

    await db.collection("analytics").add({
      event,
      metadata,
      timestamp: new Date().toISOString(),
    });

    return res.status(200).json({ message: "Analytics logged" });
  } catch (err) {
    console.error("Analytics Log Error:", err.message);
    return res.status(500).json({ error: "Logging failed" });
  }
});

/**
 * POST /smartAdvisor [Future]
 * Stub for smart diet nudging system
 */
app.post("/smartAdvisor", (req, res) => {
  return res.status(501).json({
    message: "🚀 Smart Diet Advisor is being trained. Stay tuned!",
    version: "Coming in Q4 2025",
  });
});

// Catch-all for undefined routes
app.all("*", (req, res) => {
  res.status(404).json({ error: "Route not found" });
});

// Server Bootstrap
app.listen(PORT, () => {
  console.log(`✅ NutriPlan AI backend listening at http://localhost:${PORT}`);
});
