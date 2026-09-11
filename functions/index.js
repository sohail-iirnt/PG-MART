const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// === 1. RAZORPAY WEBHOOK ===
const WEBHOOK_SECRET = "pgmart_secure_webhook_secret_2026";

exports.razorpayWebhook = onRequest(async (req, res) => {
  try {
    const signature = req.headers["x-razorpay-signature"];
    const body = req.rawBody;

    const expectedSignature = crypto
      .createHmac("sha256", WEBHOOK_SECRET)
      .update(body)
      .digest("hex");

    if (signature !== expectedSignature) {
      console.error("🚨 Invalid Razorpay Signature!");
      res.status(400).send("Invalid signature");
      return;
    }

    const payload = req.body;
    const eventType = payload.event;
    const paymentEntity = payload.payload.payment.entity;

    await admin.firestore().collection("transactions").doc(paymentEntity.id).set({
      paymentId: paymentEntity.id,
      amount: paymentEntity.amount / 100,
      status: paymentEntity.status,
      event: eventType,
      method: paymentEntity.method,
      contact: paymentEntity.contact,
      email: paymentEntity.email,
      rawPayload: payload,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`✅ Webhook processed successfully for Payment: ${paymentEntity.id}`);
    res.status(200).send("Webhook received");

  } catch (error) {
    console.error("🚨 Webhook Error: ", error);
    res.status(500).send("Server Error");
  }
});

// === 2. RICH PUSH NOTIFICATION ENGINE ===
exports.sendPushNotification = onDocumentCreated("push_campaigns/{campaignId}", async (event) => {
  const snap = event.data;

  // If the document doesn't exist, exit early
  if (!snap) {
      return;
  }

  const data = snap.data();

  const payload = {
    topic: 'all_users',
    notification: {
      title: data.title,
      body: data.body,
    },
    data: {
      image_url: data.imageUrl || '',
      product_id: data.productId || '',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    }
  };

  try {
    await admin.messaging().send(payload);
    console.log('✅ Successfully broadcasted campaign:', data.title);
  } catch (error) {
    console.error('🚨 Error broadcasting campaign:', error);
  }
});