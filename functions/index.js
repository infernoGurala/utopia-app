const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

exports.sendChatNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const message = snapshot.data();
    const chatId = event.params.chatId;
    const senderId = message.senderId;
    const text = (message.text || "").toString().trim();

    if (!senderId || !text) {
      return;
    }

    const db = admin.firestore();
    const chatSnap = await db.doc(`chats/${chatId}`).get();
    if (!chatSnap.exists) {
      logger.warn("Chat document missing for message", {chatId});
      return;
    }

    const chat = chatSnap.data() || {};
    const participants = Array.isArray(chat.participants) ? chat.participants : [];
    const recipientId = participants.find((uid) => uid !== senderId);

    if (!recipientId) {
      logger.warn("Recipient not found for chat message", {chatId, senderId});
      return;
    }

    const [senderSnap, recipientSnap] = await Promise.all([
      db.doc(`users/${senderId}`).get(),
      db.doc(`users/${recipientId}`).get(),
    ]);

    const sender = senderSnap.data() || {};
    const recipient = recipientSnap.data() || {};
    const token = recipient.fcmToken;

    if (!token) {
      logger.info("Recipient missing FCM token", {recipientId});
      return;
    }

    const senderName = sender.displayName || sender.email || "New message";
    const preview = text.length > 120 ? `${text.slice(0, 117)}...` : text;

    await admin.messaging().send({
      token,
      notification: {
        title: senderName,
        body: preview,
      },
      data: {
        type: "chat",
        chatId,
        senderId,
        senderName: senderName.toString(),
        body: preview,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "utopia_high_importance",
          icon: "ic_notification",
        },
      },
    });

    logger.info("Chat notification sent", {
      chatId,
      senderId,
      recipientId,
    });
  },
);
