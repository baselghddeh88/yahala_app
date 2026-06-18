const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const {GoogleAuth} = require("google-auth-library");

admin.initializeApp({
  projectId: "yahala-9b386",
});

exports.sendApprovalNotification = onDocumentUpdated(
    {
      document: "ads/{adId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (before.status === "approved" || after.status !== "approved") {
        return;
      }

      const userId = after.userId;

      if (!userId) {
        console.log("No userId on ad");
        return;
      }

      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        console.log("User doc not found:", userId);
        return;
      }

      const userData = userDoc.data();
      const token = userData.fcmToken;

      if (!token) {
        console.log("No fcmToken for user:", userId);
        return;
      }

      await userDoc.ref.set({
        lastApprovedAdId: event.params.adId,
        lastApprovedAdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      console.log("Sending notification to user:", userId);

      const auth = new GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
      });

      const client = await auth.getClient();
      const accessTokenResponse = await client.getAccessToken();
      const accessToken = accessTokenResponse.token;

      const response = await fetch(
          "https://fcm.googleapis.com/v1/projects/yahala-9b386/messages:send",
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: token,
                notification: {
                  title: "يا هلا",
                  body: "تمت الموافقة على إعلانك 🎉",
                },
                data: {
                  adId: event.params.adId,
                  type: "ad_approved",
                  route: "ad_details",
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                  notification: {
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      category: "OPEN_AD",
                      sound: "default",
                    },
                  },
                },
              },
            }),
          },
      );

      const data = await response.json();

      console.log("FCM response:", data);

      if (!response.ok) {
        throw new Error(JSON.stringify(data));
      }

      console.log("Approval notification sent");
    },
);

exports.sendCommunityQuestionNotification = onDocumentCreated(
    {
      document: "ads/{adId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const question = event.data.data();

      if (question.category !== "سؤال" || question.status !== "approved") {
        return;
      }

      const users = await admin.firestore().collection("users").get();
      const tokens = [];

      users.forEach((doc) => {
        const user = doc.data();
        const token = user.fcmToken;

        if (
          token &&
          typeof token === "string" &&
          doc.id !== question.userId
        ) {
          tokens.push(token);
        }
      });

      if (tokens.length === 0) {
        console.log("No FCM tokens for community question");
        return;
      }

      const title = question.title || "سؤال جديد من الجالية";
      const chunks = [];

      for (let i = 0; i < tokens.length; i += 500) {
        chunks.push(tokens.slice(i, i + 500));
      }

      await Promise.all(chunks.map((chunk) => admin.messaging()
          .sendEachForMulticast({
            tokens: chunk,
            notification: {
              title: "اسأل الجالية",
              body: title,
            },
            data: {
              adId: event.params.adId,
              type: "community_question",
              route: "question_details",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              notification: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
            apns: {
              payload: {
                aps: {
                  category: "OPEN_AD",
                  sound: "default",
                },
              },
            },
          })));

      console.log("Community question notification sent:", event.params.adId);
    },
);

exports.sendChatNotification = onDocumentCreated(
    {
      document: "chats/{chatId}/messages/{messageId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const message = event.data.data();
      const senderId = message.senderId;

      if (!senderId) {
        console.log("No senderId on chat message");
        return;
      }

      const chatDoc = await admin
          .firestore()
          .collection("chats")
          .doc(event.params.chatId)
          .get();

      if (!chatDoc.exists) {
        console.log("Chat doc not found:", event.params.chatId);
        return;
      }

      const chat = chatDoc.data();
      const participantIds = Array.isArray(chat.participantIds) ?
        chat.participantIds :
        [];
      const recipientIds = participantIds.filter((id) => id !== senderId);

      if (recipientIds.length === 0) {
        console.log("No chat recipients:", event.params.chatId);
        return;
      }

      const recipientDocs = await Promise.all(recipientIds.map((id) => admin
          .firestore()
          .collection("users")
          .doc(id)
          .get()));
      const tokens = recipientDocs
          .map((doc) => {
            const user = doc.data();
            return user && user.fcmToken;
          })
          .filter((token) => token && typeof token === "string");

      if (tokens.length === 0) {
        console.log("No FCM tokens for chat:", event.params.chatId);
        return;
      }

      const names = chat.participantNames || {};
      const senderName = message.senderName || names[senderId] || "يا هلا";
      const text = message.text || "رسالة جديدة";
      const adTitle = chat.adTitle || "";

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: senderName,
          body: text,
        },
        data: {
          type: "chat_message",
          route: "chat_thread",
          chatId: event.params.chatId,
          adTitle,
          senderName,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              category: "OPEN_CHAT",
              sound: "default",
            },
          },
        },
      });

      console.log("Chat notification sent:", event.params.chatId);
    },
);

// force redeploy 7
