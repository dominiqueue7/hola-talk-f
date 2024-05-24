const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp(functions.config().firebase);

exports.sendNewMessageNotification = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const messageData = snap.data();
      const chatId = context.params.chatId;

      if (!messageData || !messageData.author || !messageData.text) {
        return;
      }

      // Get the author and recipient information
      const authorId = messageData.author.id;
      const text = messageData.text;

      const chatDoc = await admin.firestore()
          .collection("chats").doc(chatId).get();
      const participants = chatDoc.data().participants;

      if (!participants) {
        return;
      }

      // Find the recipient
      const recipientId = participants.find((uid) => uid !== authorId);
      if (!recipientId) {
        return;
      }

      // Get recipient's FCM token
      const recipientDoc = await admin.firestore()
          .collection("users").doc(recipientId).get();
      const recipientToken = recipientDoc.data().fcmToken;

      if (!recipientToken) {
        return;
      }

      // Get author's name
      const authorDoc = await admin.firestore()
          .collection("users").doc(authorId).get();
      const authorName = authorDoc.data().name;

      // Create the notification payload
      const payload = {
        notification: {
          title: `${authorName} sent you a message`,
          body: text,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        data: {
          chatId: chatId,
          authorId: authorId,
        },
      };

      // Send the notification
      return admin.messaging().sendToDevice(recipientToken, payload);
    });
