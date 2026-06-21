const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

const openAiApiKey = defineSecret("OPENAI_API_KEY");

admin.initializeApp({
  projectId: "yahala-9b386",
});

exports.formatAdDescription = onRequest(
    {
      region: "us-central1",
      cors: true,
      secrets: [openAiApiKey],
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "method-not-allowed"});
        return;
      }

      try {
        const authHeader = req.get("authorization") || "";
        const token = authHeader.startsWith("Bearer ") ?
          authHeader.slice(7) :
          "";

        if (!token) {
          res.status(401).json({error: "login-required"});
          return;
        }

        await admin.auth().verifyIdToken(token);

        const body = req.body || {};
        const title = String(body.title || "").trim().slice(0, 180);
        const description = String(body.description || "")
            .trim()
            .slice(0, 1200);
        const category = String(body.category || "").trim().slice(0, 80);
        const isArabic = body.isArabic !== false;

        if (!title && !description) {
          res.status(400).json({error: "empty-input"});
          return;
        }

        const promptLanguage = isArabic ? "Arabic" : "English";
        const response = await fetch("https://api.openai.com/v1/responses", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${openAiApiKey.value()}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            temperature: 0.72,
            max_output_tokens: 620,
            input: [
              {
                role: "system",
                content:
                  "You are a professional marketplace copywriter for a " +
                  "community classifieds app. Turn short user notes into a " +
                  "warm, complete, polished ad description that helps the " +
                  "reader understand the offer and feel invited to contact " +
                  "the advertiser. You may infer general, low-risk wording " +
                  "from the title, category, and notes, but do not invent " +
                  "specific facts such as prices, addresses, phone numbers, " +
                  "dates, discounts, legal claims, guarantees, licenses, " +
                  "availability, brand names, or exact features that were " +
                  "not provided. Do not add hashtags or emojis. Write in a " +
                  "natural human style, not as bullet points unless the " +
                  "input clearly needs a list. Keep it suitable for " +
                  "publication.",
              },
              {
                role: "user",
                content:
                  `Language: ${promptLanguage}\n` +
                  `Category: ${category}\n` +
                  `Title: ${title}\n` +
                  "Create an attractive expanded ad description from these " +
                  "details. If the notes are very short, enrich the wording " +
                  "with tasteful general marketplace copy without adding " +
                  "unprovided specifics. Aim for 2 to 4 short paragraphs, " +
                  "around 70 to 140 words:\n" +
                  description,
              },
            ],
          }),
        });

        const data = await response.json();

        if (!response.ok) {
          console.error("OpenAI formatting failed:", data);
          res.status(502).json({error: "ai-unavailable"});
          return;
        }

        let output = data.output_text || "";

        if (!output && Array.isArray(data.output)) {
          output = data.output
              .reduce((parts, item) => {
                const content = Array.isArray(item.content) ?
                  item.content :
                  [];

                content.forEach((piece) => {
                  if (piece && piece.text) parts.push(piece.text);
                });

                return parts;
              }, [])
              .join("\n")
              .trim();
        }

        if (!output) {
          res.status(502).json({error: "empty-ai-output"});
          return;
        }

        res.json({description: output.trim().slice(0, 1200)});
      } catch (error) {
        console.error("formatAdDescription error:", error);
        res.status(500).json({error: "format-failed"});
      }
    },
);

/**
 * Returns a readable title for ad notifications.
 * @param {Object} ad Firestore ad data.
 * @return {string} Notification title text.
 */
function adTitle(ad) {
  return ad.title || ad.description || "إعلانك";
}

/**
 * Returns a readable review type for admin notifications.
 * @param {Object} ad Firestore ad data.
 * @return {string} Review type label.
 */
function adReviewType(ad) {
  const placement = String(ad.adPlacement || "");
  const paidType = String(ad.paidAdType || "").toLowerCase();
  const category = String(ad.category || "");

  if (category === "كوبون" || category === "سؤال") return "مجاني";
  if (placement === "vip_slider" || paidType === "home_vip") return "VIP";
  if (placement === "featured" || paidType === "featured") return "مميز";
  if (placement === "category_top" || paidType === "category_top") {
    return "أولوية قسم";
  }
  return "مجاني";
}

/**
 * Checks if a user document belongs to an admin.
 * @param {string} id Firestore document id.
 * @param {Object} user Firestore user data.
 * @return {boolean} Whether the user is an admin.
 */
function isAdminUser(id, user) {
  return id === "samghddeh@gmail.com" ||
    user.email === "samghddeh@gmail.com" ||
    user.isAdmin === true ||
    user.IsAdmin === true ||
    user.role === "admin";
}

/**
 * Sends one notification to one FCM token.
 * @param {string} token FCM token.
 * @param {Object} message FCM message body.
 * @return {Promise<void>} Resolves after the message is sent.
 */
async function sendToToken(token, message) {
  if (!token || typeof token !== "string") return;

  await admin.messaging().send({
    token,
    ...message,
  });
}

/**
 * Sends one notification payload to many FCM tokens.
 * @param {string[]} tokens FCM tokens.
 * @param {Object} message FCM message body.
 * @return {Promise<void>} Resolves after all chunks are sent.
 */
async function sendToTokens(tokens, message) {
  const cleanTokens = [...new Set(tokens)]
      .filter((token) => token && typeof token === "string");

  if (cleanTokens.length === 0) return;

  for (let i = 0; i < cleanTokens.length; i += 500) {
    await admin.messaging().sendEachForMulticast({
      tokens: cleanTokens.slice(i, i + 500),
      ...message,
    });
  }
}

exports.notifyAdminsForPendingAd = onDocumentCreated(
    {
      document: "ads/{adId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const ad = event.data.data();

      if (ad.status !== "pending") return;

      const users = await admin.firestore().collection("users").get();
      const tokens = [];

      users.forEach((doc) => {
        const user = doc.data();
        if (isAdminUser(doc.id, user) && user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      });

      await sendToTokens(tokens, {
        notification: {
          title: "إعلان جديد بانتظار المراجعة",
          body: `${adReviewType(ad)} - ${adTitle(ad)}`,
        },
        data: {
          adId: event.params.adId,
          type: "admin_pending_ad",
          route: "admin",
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
              category: "OPEN_ADMIN",
              sound: "default",
            },
          },
        },
      });

      console.log("Pending ad admin notification sent:", event.params.adId);
    },
);

exports.notifyAdminsForPendingAdUpdate = onDocumentUpdated(
    {
      document: "ads/{adId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (before.status === "pending" || after.status !== "pending") return;

      const users = await admin.firestore().collection("users").get();
      const tokens = [];

      users.forEach((doc) => {
        const user = doc.data();
        if (isAdminUser(doc.id, user) && user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      });

      await sendToTokens(tokens, {
        notification: {
          title: "تعديل إعلان بانتظار المراجعة",
          body: `${adReviewType(after)} - ${adTitle(after)}`,
        },
        data: {
          adId: event.params.adId,
          type: "admin_pending_ad",
          route: "admin",
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
              category: "OPEN_ADMIN",
              sound: "default",
            },
          },
        },
      });

      console.log("Pending ad update admin notification sent:",
          event.params.adId);
    },
);

exports.sendApprovalNotification = onDocumentUpdated(
    {
      document: "ads/{adId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (before.status === after.status ||
          !["approved", "rejected"].includes(after.status)) {
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
        lastAdStatusId: event.params.adId,
        lastAdStatus: after.status,
        lastAdStatusAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(after.status === "approved" ? {
          lastApprovedAdId: event.params.adId,
          lastApprovedAdAt: admin.firestore.FieldValue.serverTimestamp(),
        } : {}),
      }, {merge: true});

      const approved = after.status === "approved";
      const reason = after.rejectionReason || "راجع سبب الرفض داخل التطبيق";
      const notification = approved ?
        {
          title: "يا هلا",
          body: "تمت الموافقة على إعلانك 🎉",
        } :
        {
          title: "تم رفض إعلانك",
          body: reason,
        };

      await sendToToken(token, {
        notification,
        data: {
          adId: event.params.adId,
          type: approved ? "ad_approved" : "ad_rejected",
          route: "ad_details",
          rejectionReason: reason,
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
      });

      console.log("Ad status notification sent:", after.status);
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

exports.notifyAdminsForDeletionRequest = onDocumentCreated(
    {
      document: "deletionRequests/{userId}",
      region: "us-central1",
      serviceAccount: "yahala-9b386@appspot.gserviceaccount.com",
    },
    async (event) => {
      const request = event.data.data();
      const users = await admin.firestore().collection("users").get();
      const tokens = [];

      users.forEach((doc) => {
        const user = doc.data();
        if (isAdminUser(doc.id, user) && user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      });

      const name = request.name || request.email || "مستخدم";
      const reason = request.reason || "بدون سبب";

      await sendToTokens(tokens, {
        notification: {
          title: "طلب حذف حساب",
          body: `${name}: ${reason}`,
        },
        data: {
          userId: event.params.userId,
          type: "admin_deletion_request",
          route: "admin",
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
              category: "OPEN_ADMIN",
              sound: "default",
            },
          },
        },
      });

      console.log("Deletion request admin notification sent:",
          event.params.userId);
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
