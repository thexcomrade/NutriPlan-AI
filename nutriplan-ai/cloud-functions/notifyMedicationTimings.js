D:\nutriplan-ai\cloud-functions\notifyMedicationTimings.js

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const moment = require("moment-timezone");

admin.initializeApp();
const db = admin.firestore();

const TIMEZONE = "Asia/Kolkata";

// Helper to send FCM notification
async function sendNotification(token, title, body) {
  try {
    await admin.messaging().send({
      token,
      notification: {
        title,
        body,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
    console.log(`Notification sent to token: ${token}`);
  } catch (err) {
    console.error("Error sending notification:", err);
  }
}

// Utility: formats hour to 2-digit string
const formatHour = (hr) => (hr < 10 ? `0${hr}` : `${hr}`);

exports.scheduledMedicationNotifier = functions.pubsub
  .schedule("every 5 minutes")
  .timeZone(TIMEZONE)
  .onRun(async () => {
    const now = moment().tz(TIMEZONE);
    const currentHour = formatHour(now.hour());
    const currentMinute = formatHour(now.minute());
    const currentTime = `${currentHour}:${currentMinute}`;

    console.log(`Checking for medications scheduled at ${currentTime}`);

    try {
      const snapshot = await db
        .collection("medications")
        .where("time", "==", currentTime)
        .get();

      if (snapshot.empty) {
        console.log("No medications scheduled at this time.");
        return null;
      }

      const promises = [];

      snapshot.forEach((doc) => {
        const data = doc.data();
        const userId = data.userId;
        const medicationName = data.name || "Unnamed Medicine";
        const note = data.note || "Don't forget your dose!";

        promises.push(
          db
            .collection("users")
            .doc(userId)
            .get()
            .then(async (userDoc) => {
              if (!userDoc.exists) {
                console.warn(`User not found: ${userId}`);
                return;
              }
              const userData = userDoc.data();
              const token = userData.fcmToken;

              if (!token) {
                console.warn(`No FCM token for user ${userId}`);
                return;
              }

              const title = "Medication Reminder";
              const body = `Time to take: ${medicationName}.\n${note}`;
              await sendNotification(token, title, body);
            })
        );
      });

      await Promise.all(promises);
      console.log("All reminders processed.");
    } catch (error) {
      console.error("Error in scheduled medication notifier:", error);
    }
  });

// Callable function to add a medication reminder
exports.addMedicationReminder = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;

  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Only authenticated users can add medications."
    );
  }

  const { name, time, note } = data;

  if (!name || !time) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required fields: name or time."
    );
  }

  try {
    await db.collection("medications").add({
      userId: uid,
      name,
      time,
      note: note || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true, message: "Medication reminder added successfully." };
  } catch (err) {
    console.error("Error adding medication:", err);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to add medication reminder."
    );
  }
});

// HTTP function for debug/test
exports.testNotification = functions.https.onRequest(async (req, res) => {
  const { token, title, body } = req.query;

  if (!token || !title || !body) {
    return res.status(400).send("Missing required query parameters.");
  }

  try {
    await sendNotification(token, title, body);
    res.status(200).send("Test notification sent successfully.");
  } catch (err) {
    console.error("Failed to send test notification:", err);
    res.status(500).send("Error sending test notification.");
  }
});