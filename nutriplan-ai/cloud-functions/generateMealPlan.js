/**
 * generateMealPlan.js
 * Cloud Function to generate personalized meal plans for users
 * using datasets: diet profiles, medical meals, diet types.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const csv = require("csv-parser");
const fs = require("fs");
const path = require("path");

admin.initializeApp();
const db = admin.firestore();

// --- CSV Loader Utility ---
async function loadCSV(filepath) {
  return new Promise((resolve, reject) => {
    const results = [];
    fs.createReadStream(filepath)
      .pipe(csv())
      .on("data", (data) => results.push(data))
      .on("end", () => resolve(results))
      .on("error", reject);
  });
}

// --- Retry Wrapper ---
async function retryAsync(fn, retries = 3, delay = 1000) {
  while (retries-- > 0) {
    try {
      return await fn();
    } catch (err) {
      if (retries === 0) throw err;
      await new Promise((res) => setTimeout(res, delay));
    }
  }
}

// --- Cache Datasets for Optimization ---
let cachedMeals = null;
let cachedDiets = null;
let cachedRecommendations = null;

async function loadDatasets() {
  if (!cachedMeals || !cachedDiets || !cachedRecommendations) {
    const base = "/mnt/data"; // mount path for CSVs
    [cachedMeals, cachedDiets, cachedRecommendations] = await Promise.all([
      loadCSV(path.join(base, "5a01461e-fbc0-4115-bd2c-115c90dce88e.csv")),
      loadCSV(path.join(base, "All_Diets.csv")),
      loadCSV(path.join(base, "diet_recommendations_dataset.csv")),
    ]);
  }
  return {
    meals: cachedMeals,
    diets: cachedDiets,
    recommendations: cachedRecommendations,
  };
}

// --- Profile Validation ---
function validateProfile(profile) {
  const requiredFields = ["goal", "activity_level", "diet_type", "preferred_cuisine"];
  for (const field of requiredFields) {
    if (!profile[field]) throw new Error(`Missing profile field: ${field}`);
  }
  if (typeof profile.age !== "number" || profile.age <= 0)
    throw new Error("Invalid age in profile.");
  if (!["male", "female", "other"].includes(profile.gender))
    throw new Error("Invalid gender in profile.");
}

// --- Smart Nutrition Calculator ---
function computeNutrition(profile) {
  const baseCalories = 2000;
  const activityMap = {
    sedentary: 1.0,
    light: 1.2,
    moderate: 1.5,
    active: 1.75,
    "very active": 2.0,
  };
  const multiplier = activityMap[profile.activity_level] || 1.5;

  let goalAdjust = 0;
  switch (profile.goal) {
    case "weight loss":
      goalAdjust = -500;
      break;
    case "weight gain":
      goalAdjust = 500;
      break;
    default:
      goalAdjust = 0;
  }

  const calories = Math.max(1200, Math.round((baseCalories + goalAdjust) * multiplier));

  return {
    calories,
    protein: Math.round((calories * 0.3) / 4),
    carbs: Math.round((calories * 0.4) / 4),
    fats: Math.round((calories * 0.3) / 9),
  };
}

// --- Meal Filtering Based on Profile and Health ---
function filterMeals(meals, profile, medicalFlags = []) {
  return meals
    .filter((meal) => {
      const mealName = meal.Meal?.toLowerCase() || "";
      const cuisine = meal.Cuisine?.toLowerCase() || "";

      if (
        profile.excluded_items &&
        profile.excluded_items.some((ex) => mealName.includes(ex.toLowerCase()))
      )
        return false;

      if (
        profile.preferred_cuisine &&
        cuisine !== profile.preferred_cuisine.toLowerCase()
      )
        return false;

      if (
        medicalFlags.length > 0 &&
        !medicalFlags.every((cond) =>
          (meal.MedicalSafeFor || "").toLowerCase().includes(cond.toLowerCase())
        )
      )
        return false;

      if (profile.goal === "weight loss" && parseInt(meal.Fats) > 15) return false;

      return true;
    })
    .map((meal) => ({
      name: meal.Meal,
      calories: parseInt(meal.Calories),
      protein: parseInt(meal.Protein),
      carbs: parseInt(meal.Carbs),
      fats: parseInt(meal.Fats),
      cuisine: meal.Cuisine,
      tags: meal.DietTags?.split(",").map((t) => t.trim().toLowerCase()) || [],
    }));
}

// --- Construct 3-Meal Daily Plan ---
function generateMealPlanFromFilteredMeals(filtered) {
  const mealPlan = {
    breakfast: filtered.find((m) => m.tags.includes("breakfast")),
    lunch: filtered.find((m) => m.tags.includes("lunch")),
    dinner: filtered.find((m) => m.tags.includes("dinner")),
  };

  const remaining = filtered.filter(
    (m) => ![mealPlan.breakfast, mealPlan.lunch, mealPlan.dinner].includes(m)
  );

  for (const key of ["breakfast", "lunch", "dinner"]) {
    if (!mealPlan[key]) mealPlan[key] = remaining.shift() || null;
  }

  return mealPlan;
}

// --- Recommendation Matcher ---
function getMatchedRecommendations(profile, recs) {
  return recs.find((rec) => {
    return (
      rec.Gender.toLowerCase() === profile.gender.toLowerCase() &&
      rec.ActivityLevel.toLowerCase() === profile.activity_level &&
      rec.Goal.toLowerCase() === profile.goal &&
      rec.DietType.toLowerCase() === profile.diet_type &&
      rec.PreferredCuisine.toLowerCase() === profile.preferred_cuisine
    );
  });
}

// --- Cloud Function Entry ---
exports.generateMealPlan = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }

    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "Missing userId in request body" });

    const userDoc = await retryAsync(() => db.collection("users").doc(userId).get());
    if (!userDoc.exists) return res.status(404).json({ error: "User not found" });
    const userProfile = userDoc.data();

    const medicalDoc = await retryAsync(() =>
      db.collection("medical_records").doc(userId).get()
    );
    const medicalRecord = medicalDoc.exists ? medicalDoc.data() : { conditions: [], allergies: [] };

    const profile = {
      goal: (userProfile.preferences?.goal || "maintain").toLowerCase(),
      activity_level: (userProfile.preferences?.activity_level || "moderate").toLowerCase(),
      budget: (userProfile.preferences?.budget || "medium").toLowerCase(),
      diet_type: (userProfile.preferences?.diet_type || "balanced").toLowerCase(),
      excluded_items: userProfile.preferences?.excluded_items || [],
      preferred_cuisine: userProfile.preferences?.preferred_cuisine || "Indian",
      mode: userProfile.preferences?.mode || "eco",
      age: userProfile.age || 25,
      gender: userProfile.gender || "other",
    };

    validateProfile(profile);

    const medicalFlags = (medicalRecord.conditions || []).map((c) => c.toLowerCase());

    const { meals, diets, recommendations } = await loadDatasets();

    const nutritionGoals = computeNutrition(profile);

    const matchedRec = getMatchedRecommendations(profile, recommendations);
    const customMeals = matchedRec
      ? matchedRec.RecommendedMeals.split(",").map((m) => m.trim())
      : [];

    const filteredMeals = filterMeals(meals, profile, medicalFlags).filter((m) =>
      customMeals.length > 0 ? customMeals.includes(m.name) : true
    );

    if (filteredMeals.length < 3) {
      return res.status(500).json({
        error: "Not enough suitable meals found for this profile.",
        profile,
        found: filteredMeals.length,
      });
    }

    const mealPlan = generateMealPlanFromFilteredMeals(filteredMeals);

    await db.collection("meal_plans").doc(userId).set({
      mealPlan,
      nutritionGoals,
      metadata: {
        profileUsed: profile,
        medicalConditions: medicalFlags,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    return res.status(200).json({
      message: "Meal plan generated successfully",
      mealPlan,
      nutritionGoals,
      profileUsed: profile,
    });
  } catch (error) {
    console.error("Meal Plan Generation Error:", error.message, error.stack);
    return res.status(500).json({ error: error.message || "Internal Server Error" });
  }
});
