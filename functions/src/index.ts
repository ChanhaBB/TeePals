import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

// ============================================
// deleteUserAccount: Callable function for account deletion
// Cascades through all user data in Firestore, Storage, and Auth
// ============================================

export const deleteUserAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in to delete account.");
  }

  const uid = context.auth.uid;
  console.log(`🗑️ Starting account deletion for user: ${uid}`);

  try {
    // 1. Bidirectional social graph cleanup
    await cleanupSocialGraph(uid);

    // 2. Delete user-owned document trees
    await deleteSubcollection(`follows/${uid}/following`);
    await deleteSubcollection(`follows/${uid}/followers`);
    await deleteSubcollection(`blocks/${uid}/blocked`);
    await deleteSubcollection(`notifications/${uid}/items`);
    await deleteSubcollection(`pendingFeedback/${uid}/items`);

    // 3. Round participation cleanup
    await cleanupRoundParticipation(uid);

    // 4. Posts and comments: anonymize author
    await anonymizeUserContent(uid);

    // 5. Delete top-level user documents
    const topLevelDocs = [
      db.collection("users").doc(uid),
      db.collection("profiles_public").doc(uid),
      db.collection("profiles_private").doc(uid),
      db.collection("userStats").doc(uid),
      db.collection("follows").doc(uid),
      db.collection("blocks").doc(uid),
      db.collection("notifications").doc(uid),
      db.collection("pendingFeedback").doc(uid),
    ];
    const batch = db.batch();
    topLevelDocs.forEach((ref) => batch.delete(ref));
    await batch.commit();

    // 6. Storage cleanup
    await deleteStorageFolder(`profilePhotos/${uid}`);
    await deleteStorageFolder(`postPhotos/${uid}`);

    // 7. Delete Firebase Auth account
    await admin.auth().deleteUser(uid);

    console.log(`✅ Account deletion complete for user: ${uid}`);
    return {success: true};
  } catch (error) {
    console.error(`❌ Account deletion failed for user ${uid}:`, error);
    throw new functions.https.HttpsError("internal", "Account deletion failed. Please try again.");
  }
});

// Helper: Delete all documents in a subcollection (batched)
async function deleteSubcollection(path: string): Promise<void> {
  const snapshot = await db.collection(path).limit(500).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size === 500) {
    await deleteSubcollection(path);
  }
}

// Helper: Clean up bidirectional follow relationships
async function cleanupSocialGraph(uid: string): Promise<void> {
  // Remove uid from each person they follow's followers list
  const followingSnap = await db.collection(`follows/${uid}/following`).get();
  const followingBatch = db.batch();
  followingSnap.docs.forEach((doc) => {
    followingBatch.delete(
      db.collection("follows").doc(doc.id).collection("followers").doc(uid)
    );
  });
  if (!followingSnap.empty) await followingBatch.commit();

  // Remove uid from each follower's following list
  const followersSnap = await db.collection(`follows/${uid}/followers`).get();
  const followersBatch = db.batch();
  followersSnap.docs.forEach((doc) => {
    followersBatch.delete(
      db.collection("follows").doc(doc.id).collection("following").doc(uid)
    );
  });
  if (!followersSnap.empty) await followersBatch.commit();
}

// Helper: Clean up round memberships, chat metadata, feedback
async function cleanupRoundParticipation(uid: string): Promise<void> {
  // Members (collection group query)
  const membersSnap = await db.collectionGroup("members")
    .where("uid", "==", uid).get();
  if (!membersSnap.empty) {
    const batch = db.batch();
    membersSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // Chat metadata
  const chatMetaSnap = await db.collectionGroup("chatMetadata")
    .where("uid", "==", uid).get();
  if (!chatMetaSnap.empty) {
    const batch = db.batch();
    chatMetaSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // Feedback
  const feedbackSnap = await db.collectionGroup("feedback")
    .where("reviewerUid", "==", uid).get();
  if (!feedbackSnap.empty) {
    const batch = db.batch();
    feedbackSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // Endorsements (as reviewer)
  const endorseSnap = await db.collectionGroup("endorsements")
    .where("reviewerUid", "==", uid).get();
  if (!endorseSnap.empty) {
    const batch = db.batch();
    endorseSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // Incidents (as reviewer)
  const incidentSnap = await db.collectionGroup("incidents")
    .where("reviewerUid", "==", uid).get();
  if (!incidentSnap.empty) {
    const batch = db.batch();
    incidentSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

// Helper: Anonymize user's posts, comments, upvotes, likes, messages
async function anonymizeUserContent(uid: string): Promise<void> {
  // Anonymize posts
  const postsSnap = await db.collection("posts")
    .where("authorUid", "==", uid).get();
  if (!postsSnap.empty) {
    const batch = db.batch();
    postsSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        authorUid: "deleted",
        authorNickname: "Deleted User",
        authorPhotoUrl: null,
      });
    });
    await batch.commit();
  }

  // Anonymize comments
  const commentsSnap = await db.collectionGroup("comments")
    .where("authorUid", "==", uid).get();
  if (!commentsSnap.empty) {
    const batch = db.batch();
    commentsSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        authorUid: "deleted",
        authorNickname: "Deleted User",
        authorPhotoUrl: null,
      });
    });
    await batch.commit();
  }

  // Note: upvote docs use doc ID = uid rather than a uid field,
  // so collection group queries can't easily find them. They are harmless
  // orphaned docs that reference a now-deleted user and will not surface in UI.

  // Anonymize chat messages
  const messagesSnap = await db.collectionGroup("messages")
    .where("senderUid", "==", uid).get();
  if (!messagesSnap.empty) {
    const batch = db.batch();
    messagesSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        senderUid: "deleted",
        senderNickname: "Deleted User",
        senderPhotoUrl: null,
      });
    });
    await batch.commit();
  }
}

// Helper: Delete all files in a Storage folder
async function deleteStorageFolder(prefix: string): Promise<void> {
  try {
    const bucket = storage.bucket();
    const [files] = await bucket.getFiles({prefix});
    if (files.length === 0) return;

    await Promise.all(files.map((file) => file.delete()));
    console.log(`🗑️ Deleted ${files.length} files from ${prefix}`);
  } catch (error) {
    console.warn(`⚠️ Storage cleanup failed for ${prefix}:`, error);
  }
}

// ============================================
// onUpvoteWrite: Maintain upvote counts
// ============================================

export const onUpvoteWrite = functions.firestore
  .document("posts/{postId}/upvotes/{uid}")
  .onWrite(async (change, context) => {
    const postId = context.params.postId as string;
    const postRef = db.collection("posts").doc(postId);
    const statsRef = db.collection("postStats").doc(postId);

    const wasCreated = !change.before.exists && change.after.exists;
    const wasDeleted = change.before.exists && !change.after.exists;

    if (!wasCreated && !wasDeleted) {
      // Update without create/delete (shouldn't happen for upvotes, but safe)
      return;
    }

    const increment = wasCreated ? 1 : -1;

    try {
      await db.runTransaction(async (transaction) => {
        // ALL READS MUST HAPPEN FIRST (before any writes)
        const postDoc = await transaction.get(postRef);
        const statsDoc = await transaction.get(statsRef);

        // Calculate new counts
        const currentCount = postDoc.data()?.upvoteCount || 0;
        const newCount = Math.max(0, currentCount + increment);

        // NOW DO WRITES
        // Update post upvoteCount (never go below 0)
        transaction.update(postRef, {
          upvoteCount: newCount,
        });

        // Update or create postStats
        if (statsDoc.exists) {
          const statsCurrentCount = statsDoc.data()?.upvoteCount || 0;
          const statsNewCount = Math.max(0, statsCurrentCount + increment);
          transaction.update(statsRef, {
            upvoteCount: statsNewCount,
            lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          // Initialize postStats if doesn't exist
          transaction.set(statsRef, {
            postId,
            upvoteCount: Math.max(0, increment),
            commentCount: 0,
            lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
            hotScore7d: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      console.log(
        `✅ Updated upvote count for post ${postId} (${increment > 0 ? "+" : ""}${increment})`
      );
    } catch (error) {
      console.error(`❌ Error updating upvote count for post ${postId}:`, error);
      throw error;
    }
  });

// ============================================
// onCommentWrite: Maintain comment counts
// ============================================

export const onCommentWrite = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onWrite(async (change, context) => {
    const postId = context.params.postId as string;
    const postRef = db.collection("posts").doc(postId);
    const statsRef = db.collection("postStats").doc(postId);

    const wasCreated = !change.before.exists && change.after.exists;
    const wasDeleted = change.before.exists && !change.after.exists;

    if (!wasCreated && !wasDeleted) {
      // Update without create/delete (edit comment)
      return;
    }

    const increment = wasCreated ? 1 : -1;

    try {
      await db.runTransaction(async (transaction) => {
        // ALL READS MUST HAPPEN FIRST (before any writes)
        const postDoc = await transaction.get(postRef);
        const statsDoc = await transaction.get(statsRef);

        // Calculate new counts
        const currentCount = postDoc.data()?.commentCount || 0;
        const newCount = Math.max(0, currentCount + increment);

        // NOW DO WRITES
        // Update post commentCount (never go below 0)
        transaction.update(postRef, {
          commentCount: newCount,
        });

        // Update or create postStats
        if (statsDoc.exists) {
          const statsCurrentCount = statsDoc.data()?.commentCount || 0;
          const statsNewCount = Math.max(0, statsCurrentCount + increment);
          transaction.update(statsRef, {
            commentCount: statsNewCount,
            lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          // Initialize postStats if doesn't exist
          transaction.set(statsRef, {
            postId,
            upvoteCount: 0,
            commentCount: Math.max(0, increment),
            lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
            hotScore7d: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      console.log(
        `✅ Updated comment count for post ${postId} (${increment > 0 ? "+" : ""}${increment})`
      );
    } catch (error) {
      console.error(`❌ Error updating comment count for post ${postId}:`, error);
      throw error;
    }
  });

// ============================================
// onPostCreate: Initialize stats and update userStats
// ============================================

export const onPostCreate = functions.firestore
  .document("posts/{postId}")
  .onCreate(async (snap, context) => {
    const postId = context.params.postId as string;
    const post = snap.data();
    const authorUid = post.authorUid as string;

    try {
      // Initialize postStats
      await db.collection("postStats").doc(postId).set({
        postId,
        upvoteCount: 0,
        commentCount: 0,
        lastEngagementAt: post.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        hotScore7d: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Initialized postStats for post ${postId}`);

      // Update userStats
      const userStatsRef = db.collection("userStats").doc(authorUid);
      const userStatsDoc = await userStatsRef.get();

      if (userStatsDoc.exists) {
        // Increment post count
        await userStatsRef.update({
          postCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Recompute isNewAuthor
        const stats = userStatsDoc.data()!;
        const accountCreatedAt = stats.accountCreatedAt?.toDate();
        const postCount = (stats.postCount || 0) + 1;

        const accountAgeDays = accountCreatedAt
          ? (Date.now() - accountCreatedAt.getTime()) / (1000 * 60 * 60 * 24)
          : 0;
        const isNewAuthor = accountAgeDays < 30 || postCount < 5;

        await userStatsRef.update({ isNewAuthor });

        console.log(`✅ Updated userStats for ${authorUid} (postCount: ${postCount}, isNewAuthor: ${isNewAuthor})`);
      } else {
        // Create userStats for new author
        await userStatsRef.set({
          userId: authorUid,
          accountCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
          postCount: 1,
          isNewAuthor: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Created userStats for new author ${authorUid}`);
      }
    } catch (error) {
      console.error(`❌ Error in onPostCreate for post ${postId}:`, error);
      throw error;
    }
  });

// ============================================
// computeHotScores: Scheduled function to update hotScore7d
// Runs every 15 minutes
// ============================================

export const computeHotScores = functions.pubsub
  .schedule("every 15 minutes")
  .onRun(async (context) => {
    console.log("🔥 Starting hotScore computation...");

    const cutoffDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // 7 days ago

    try {
      const statsSnapshot = await db
        .collection("postStats")
        .where("lastEngagementAt", ">", cutoffDate)
        .get();

      console.log(`📊 Found ${statsSnapshot.size} posts to update`);

      const batch = db.batch();
      let count = 0;

      statsSnapshot.docs.forEach((doc) => {
        const stats = doc.data();
        const lastEngagementAt = stats.lastEngagementAt?.toDate();

        if (!lastEngagementAt) {
          return;
        }

        // Compute hot score
        const ageHours = (Date.now() - lastEngagementAt.getTime()) / (1000 * 60 * 60);
        const recencyBoost = Math.max(0, 5 - ageHours / 24); // Decays over days
        const engagementScore = Math.log(
          1 + (stats.upvoteCount || 0) + 2 * (stats.commentCount || 0)
        );
        const hotScore = engagementScore + recencyBoost;

        batch.update(doc.ref, {
          hotScore7d: hotScore,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        count++;

        // Firestore batch limit is 500
        if (count >= 500) {
          return;
        }
      });

      if (count > 0) {
        await batch.commit();
        console.log(`✅ Updated ${count} hotScores`);
      } else {
        console.log("ℹ️ No hotScores to update");
      }
    } catch (error) {
      console.error("❌ Error computing hotScores:", error);
      throw error;
    }
  });

// ============================================
// PHASE 5: NOTIFICATIONS
// ============================================

// Helper: Fetch profile for denormalized data
async function fetchProfile(uid: string): Promise<{nickname: string; photoUrl: string | null} | null> {
  try {
    const profileDoc = await db.collection("profiles_public").doc(uid).get();
    if (!profileDoc.exists) {
      return null;
    }
    const data = profileDoc.data()!;
    return {
      nickname: data.nickname || "Unknown",
      photoUrl: data.photoUrls?.[0] || null,
    };
  } catch (error) {
    console.error(`Error fetching profile for ${uid}:`, error);
    return null;
  }
}

// Helper: Send FCM push notification (fire-and-forget — never throws or blocks Firestore writes)
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return; // User hasn't granted permission yet or hasn't logged in on this device

    await admin.messaging().send({
      token: fcmToken,
      notification: {title, body},
      data, // notificationType, targetType, targetId for tap routing on the client
      apns: {
        payload: {aps: {sound: "default", badge: 1}},
      },
    });

    console.log(`✅ Push sent to ${userId}: ${data.notificationType}`);
  } catch (err: any) {
    // Invalid / expired token — log but never propagate so Firestore write still succeeds.
    console.warn(`⚠️ Push failed for ${userId}: ${err.code || err.message}`);
  }
}

// Helper: Create notification — returns the Firestore document ID so it can be
// included in the FCM data payload for client-side mark-as-read on push tap.
async function createNotification(
  userId: string,
  notifData: {
    type: string;
    actorUid?: string | null;
    actorNickname?: string;
    actorPhotoUrl?: string | null;
    targetId?: string;
    targetType?: string;
    title: string;
    body: string;
    metadata?: Record<string, any>;
  }
): Promise<string> {
  try {
    const docRef = await db
      .collection("notifications")
      .doc(userId)
      .collection("items")
      .add({
        ...notifData,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`✅ Created notification for ${userId}: ${notifData.type}`);
    return docRef.id;
  } catch (error) {
    console.error(`❌ Error creating notification for ${userId}:`, error);
    throw error;
  }
}

// ============================================
// onRoundMemberWrite: Join requests, invitations, acceptances
// ============================================

export const onRoundMemberWrite = functions.firestore
  .document("rounds/{roundId}/members/{memberId}")
  .onWrite(async (change, context) => {
    const roundId = context.params.roundId as string;
    const before = change.before.data();
    const after = change.after.data();

    // Skip if deleted or no status change
    if (!after || before?.status === after.status) {
      return;
    }

    try {
      // Fetch round data
      const roundDoc = await db.collection("rounds").doc(roundId).get();
      if (!roundDoc.exists) {
        console.log(`Round ${roundId} not found`);
        return;
      }

      const roundData = roundDoc.data()!;
      const hostUid = roundData.hostUid as string;
      const memberUid = after.uid as string;
      const courseName = roundData.chosenCourse?.name || "a round";
      const roundDate = roundData.startTime?.toDate().toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      }) || "";

      // 1. Join request submitted → notify host
      // Trigger on: first request OR re-request after cancel/decline/removal
      if ((!before || before.status === "left" || before.status === "declined" || before.status === "removed") && after.status === "requested") {
        const requesterProfile = await fetchProfile(memberUid);
        const notifBody = `${requesterProfile?.nickname || "Someone"} requested to join your round`;

        const joinReqNotifId = await createNotification(hostUid, {
          type: "roundJoinRequest",
          actorUid: memberUid,
          actorNickname: requesterProfile?.nickname || "Someone",
          actorPhotoUrl: requesterProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Join Request",
          body: notifBody,
          metadata: {roundName: courseName, roundDate: roundDate},
        });
        await sendPushNotification(hostUid, "Join Request", notifBody, {
          notificationType: "roundJoinRequest",
          targetType: "round",
          targetId: roundId,
          notifId: joinReqNotifId,
        });
      }

      // 2. Request accepted → notify member
      if (before?.status === "requested" && after.status === "accepted") {
        const hostProfile = await fetchProfile(hostUid);
        const notifBody = `Your request to join the round was accepted`;

        const acceptNotifId = await createNotification(memberUid, {
          type: "roundJoinAccepted",
          actorUid: hostUid,
          actorNickname: hostProfile?.nickname || "Host",
          actorPhotoUrl: hostProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Request Accepted",
          body: notifBody,
          metadata: {roundName: courseName, roundDate: roundDate},
        });
        await sendPushNotification(memberUid, "Request Accepted", notifBody, {
          notificationType: "roundJoinAccepted",
          targetType: "round",
          targetId: roundId,
          notifId: acceptNotifId,
        });
      }

      // 3. Request declined → notify member
      if (before?.status === "requested" && after.status === "declined") {
        const hostProfile = await fetchProfile(hostUid);
        const notifBody = `Your request to join the round was declined`;

        const declineNotifId = await createNotification(memberUid, {
          type: "roundJoinDeclined",
          actorUid: hostUid,
          actorNickname: hostProfile?.nickname || "Host",
          actorPhotoUrl: hostProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Request Declined",
          body: notifBody,
          metadata: {roundName: courseName},
        });
        await sendPushNotification(memberUid, "Request Declined", notifBody, {
          notificationType: "roundJoinDeclined",
          targetType: "round",
          targetId: roundId,
          notifId: declineNotifId,
        });
      }

      // 4. User invited → notify invitee
      // Trigger on: first invite OR re-invite after decline/left/removal
      if ((!before || before.status === "declined" || before.status === "left" || before.status === "removed") && after.status === "invited") {
        const inviterUid = after.invitedBy as string;
        const inviterProfile = await fetchProfile(inviterUid);
        const notifBody = `${inviterProfile?.nickname || "Someone"} invited you to a round`;

        const inviteNotifId = await createNotification(memberUid, {
          type: "roundInvitation",
          actorUid: inviterUid,
          actorNickname: inviterProfile?.nickname || "Someone",
          actorPhotoUrl: inviterProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Round Invitation",
          body: notifBody,
          metadata: {roundName: courseName, roundDate: roundDate},
        });
        await sendPushNotification(memberUid, "Round Invitation", notifBody, {
          notificationType: "roundInvitation",
          targetType: "round",
          targetId: roundId,
          notifId: inviteNotifId,
        });
      }

      console.log(`✅ Processed round member status change: ${before?.status || "none"} → ${after.status}`);
    } catch (error) {
      console.error(`❌ Error in onRoundMemberWrite:`, error);
      throw error;
    }
  });

// ============================================
// onChatMessage: Update-in-place chat notifications
// ============================================

export const onChatMessage = functions.firestore
  .document("rounds/{roundId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const roundId = context.params.roundId as string;

    // Skip system messages
    if (message.type === "system") {
      return;
    }

    try {
      // Fetch round data
      const roundDoc = await db.collection("rounds").doc(roundId).get();
      if (!roundDoc.exists) {
        console.log(`Round ${roundId} not found`);
        return;
      }

      const roundData = roundDoc.data()!;
      const courseName = roundData.chosenCourse?.name || "Round";
      const roundDate = roundData.startTime?.toDate().toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      }) || "";

      // Get all accepted members except sender
      const membersSnapshot = await db
        .collection("rounds")
        .doc(roundId)
        .collection("members")
        .where("status", "==", "accepted")
        .get();

      // Process each member in parallel
      const promises = membersSnapshot.docs.map(async (memberDoc) => {
        const memberData = memberDoc.data();
        const memberUid = memberData.uid as string;

        // Don't notify sender
        if (memberUid === message.senderUid) {
          return;
        }

        // Check chat metadata for mute status
        const chatMetadataRef = db
          .collection("rounds")
          .doc(roundId)
          .collection("chatMetadata")
          .doc(memberUid);

        const chatMetadataSnap = await chatMetadataRef.get();
        const chatMetadata = chatMetadataSnap.data();

        // Skip if muted
        if (chatMetadata?.isMuted) {
          return;
        }

        const now = admin.firestore.FieldValue.serverTimestamp();

        // Update chat metadata (always, even if muted)
        await chatMetadataRef.set(
          {
            uid: memberUid,
            lastMessageAt: now,
            unreadCount: admin.firestore.FieldValue.increment(1),
            lastNotifiedAt: now,
            isMuted: chatMetadata?.isMuted || false,
          },
          {merge: true}
        );

        // Find existing notification for this round
        const existingNotifsSnapshot = await db
          .collection("notifications")
          .doc(memberUid)
          .collection("items")
          .where("type", "==", "roundChatMessage")
          .where("targetId", "==", roundId)
          .limit(1)
          .get();

        // Generic message body instead of showing actual message content
        const messagePreview = "New message in round chat";

        const title = roundDate ? `${courseName} • ${roundDate}` : courseName;

        let chatNotifId: string;

        if (!existingNotifsSnapshot.empty) {
          // Update existing notification with latest message
          const existingNotif = existingNotifsSnapshot.docs[0];
          chatNotifId = existingNotif.id;
          await existingNotif.ref.update({
            actorUid: message.senderUid,
            actorNickname: message.senderNickname,
            actorPhotoUrl: message.senderPhotoUrl || null,
            title: title,
            body: messagePreview,
            updatedAt: now,
            isRead: false, // Mark as unread when new message arrives
          });

          console.log(`✅ Updated chat notification for ${memberUid} in round ${roundId}`);
        } else {
          // Create new notification (first message in this round)
          const chatDocRef = await db
            .collection("notifications")
            .doc(memberUid)
            .collection("items")
            .add({
              type: "roundChatMessage",
              actorUid: message.senderUid,
              actorNickname: message.senderNickname,
              actorPhotoUrl: message.senderPhotoUrl || null,
              targetId: roundId,
              targetType: "round",
              title: title,
              body: messagePreview,
              metadata: {
                roundName: courseName,
                roundDate: roundDate,
              },
              isRead: false,
              createdAt: now,
              updatedAt: now,
            });
          chatNotifId = chatDocRef.id;

          console.log(`✅ Created chat notification for ${memberUid} in round ${roundId}`);
        }

        // Push for every new chat message (both update and create paths)
        await sendPushNotification(memberUid, title, messagePreview, {
          notificationType: "roundChatMessage",
          targetType: "round",
          targetId: roundId,
          notifId: chatNotifId,
        });
      });

      await Promise.all(promises);
      console.log(`✅ Processed chat message notifications for round ${roundId}`);
    } catch (error) {
      console.error(`❌ Error in onChatMessage:`, error);
      throw error;
    }
  });

// ============================================
// onRoundUpdate: Round cancellations and edits
// ============================================

export const onRoundUpdate = functions.firestore
  .document("rounds/{roundId}")
  .onUpdate(async (change, context) => {
    const roundId = context.params.roundId as string;
    const before = change.before.data();
    const after = change.after.data();

    try {
      const courseName = after.chosenCourse?.name || "Round";
      const roundDate = after.startTime?.toDate().toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      }) || "";

      // 1. Round canceled
      if (before.status !== "canceled" && after.status === "canceled") {
        // Get all accepted members
        const membersSnapshot = await db
          .collection("rounds")
          .doc(roundId)
          .collection("members")
          .where("status", "==", "accepted")
          .get();

        const hostProfile = await fetchProfile(after.hostUid);

        // Notify all members except host
        const promises = membersSnapshot.docs.map(async (memberDoc) => {
          const memberData = memberDoc.data();
          const memberUid = memberData.uid as string;

          // Don't notify host (they canceled it)
          if (memberUid === after.hostUid) {
            return;
          }

          const cancelBody = `${courseName} on ${roundDate} has been canceled`;
          const cancelNotifId = await createNotification(memberUid, {
            type: "roundCancelled",
            actorUid: after.hostUid,
            actorNickname: hostProfile?.nickname || "Host",
            actorPhotoUrl: hostProfile?.photoUrl,
            targetId: roundId,
            targetType: "round",
            title: "Round Canceled",
            body: cancelBody,
            metadata: {roundName: courseName, roundDate: roundDate},
          });
          await sendPushNotification(memberUid, "Round Canceled", cancelBody, {
            notificationType: "roundCancelled",
            targetType: "round",
            targetId: roundId,
            notifId: cancelNotifId,
          });
        });

        await Promise.all(promises);
        console.log(`✅ Notified members about round cancellation: ${roundId}`);
      }

      // 2. Significant updates (time or course changed)
      const timeChanged =
        before.startTime?.toDate().getTime() !== after.startTime?.toDate().getTime();
      const courseChanged = before.chosenCourse?.name !== after.chosenCourse?.name;

      if ((timeChanged || courseChanged) && after.status !== "canceled") {
        // Get all accepted members
        const membersSnapshot = await db
          .collection("rounds")
          .doc(roundId)
          .collection("members")
          .where("status", "==", "accepted")
          .get();

        const hostProfile = await fetchProfile(after.hostUid);

        // Notify all members except host
        const promises = membersSnapshot.docs.map(async (memberDoc) => {
          const memberData = memberDoc.data();
          const memberUid = memberData.uid as string;

          // Don't notify host (they made the changes)
          if (memberUid === after.hostUid) {
            return;
          }

          let updateDescription = "";
          if (timeChanged && courseChanged) {
            updateDescription = "Time and course updated";
          } else if (timeChanged) {
            updateDescription = "Time updated";
          } else if (courseChanged) {
            updateDescription = "Course changed";
          }

          const updateBody = `${updateDescription} for ${courseName} on ${roundDate}`;
          const updateNotifId = await createNotification(memberUid, {
            type: "roundUpdated",
            actorUid: after.hostUid,
            actorNickname: hostProfile?.nickname || "Host",
            actorPhotoUrl: hostProfile?.photoUrl,
            targetId: roundId,
            targetType: "round",
            title: "Round Updated",
            body: updateBody,
            metadata: {roundName: courseName, roundDate: roundDate},
          });
          await sendPushNotification(memberUid, "Round Updated", updateBody, {
            notificationType: "roundUpdated",
            targetType: "round",
            targetId: roundId,
            notifId: updateNotifId,
          });
        });

        await Promise.all(promises);
        console.log(`✅ Notified members about round update: ${roundId}`);
      }
    } catch (error) {
      console.error(`❌ Error in onRoundUpdate:`, error);
      throw error;
    }
  });

// ============================================
// onRoundComplete: Feedback reminder notifications
// Triggers when round status changes to "completed"
// Creates feedback reminder for all accepted members
// ============================================

export const onRoundComplete = functions.firestore
  .document("rounds/{roundId}")
  .onUpdate(async (change, context) => {
    const roundId = context.params.roundId as string;
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes to completed
    if (before.status === "completed" || after.status !== "completed") {
      return;
    }

    try {
      const courseName = after.chosenCourse?.name || "a round";

      // Get all accepted members (including host)
      const membersSnapshot = await db
        .collection("rounds")
        .doc(roundId)
        .collection("members")
        .where("status", "==", "accepted")
        .get();

      console.log(`🎯 Round ${roundId} completed. Creating feedback notifications for ${membersSnapshot.size} members`);

      // Create feedback notifications for all members in parallel
      const promises = membersSnapshot.docs.map(async (memberDoc) => {
        const memberData = memberDoc.data();
        const memberUid = memberData.uid as string;

        const feedbackBody = `You played at ${courseName}. Share your experience!`;
        const fbNotifId = await createNotification(memberUid, {
          type: "feedbackReminder",
          targetId: roundId,
          targetType: "round",
          title: "Rate your playing partners",
          body: feedbackBody,
          metadata: {courseName: courseName},
        });
        await sendPushNotification(memberUid, "Rate your playing partners", feedbackBody, {
          notificationType: "feedbackReminder",
          targetType: "round",
          targetId: roundId,
          notifId: fbNotifId,
        });
      });

      await Promise.all(promises);
      console.log(`✅ Created feedback notifications for ${membersSnapshot.size} members in round ${roundId}`);
    } catch (error) {
      console.error(`❌ Error creating feedback notifications for round ${roundId}:`, error);
      throw error;
    }
  });

// ============================================
// onFollowCreate: New follower notifications
// ============================================

export const onFollowCreate = functions.firestore
  .document("follows/{userId}/followers/{followerId}")
  .onCreate(async (snap, context) => {
    const userId = context.params.userId as string;
    const followerId = context.params.followerId as string;

    try {
      const followerProfile = await fetchProfile(followerId);
      const followBody = `${followerProfile?.nickname || "Someone"} started following you`;

      const followNotifId = await createNotification(userId, {
        type: "userFollowed",
        actorUid: followerId,
        actorNickname: followerProfile?.nickname || "Someone",
        actorPhotoUrl: followerProfile?.photoUrl,
        targetId: followerId,
        targetType: "profile",
        title: "New Follower",
        body: followBody,
      });
      await sendPushNotification(userId, "New Follower", followBody, {
        notificationType: "userFollowed",
        targetType: "profile",
        targetId: followerId,
        notifId: followNotifId,
      });

      console.log(`✅ Notified ${userId} about new follower ${followerId}`);
    } catch (error) {
      console.error(`❌ Error in onFollowCreate:`, error);
      throw error;
    }
  });

// ============================================
// onUpvoteCreate: Upvote notifications with aggregation
// ============================================

export const onUpvoteCreate = functions.firestore
  .document("posts/{postId}/upvotes/{uid}")
  .onCreate(async (snap, context) => {
    const postId = context.params.postId as string;
    const upvoterUid = context.params.uid as string;

    try {
      // Fetch post to get author
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) {
        console.log(`Post ${postId} not found`);
        return;
      }

      const postData = postDoc.data()!;
      const authorUid = postData.authorUid as string;

      // Don't notify if user upvoted their own post
      if (upvoterUid === authorUid) {
        return;
      }

      const upvoterProfile = await fetchProfile(upvoterUid);

      // Check for existing upvote notification within last hour
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
      const existingNotifsSnapshot = await db
        .collection("notifications")
        .doc(authorUid)
        .collection("items")
        .where("type", "==", "postUpvoted")
        .where("targetId", "==", postId)
        .where("createdAt", ">", oneHourAgo)
        .limit(1)
        .get();

      if (!existingNotifsSnapshot.empty) {
        // Aggregate: update existing notification
        const existingNotif = existingNotifsSnapshot.docs[0];
        const existingData = existingNotif.data();
        const actorUids = existingData.actorUids || [existingData.actorUid];

        // Only add if not already in the list
        if (!actorUids.includes(upvoterUid)) {
          actorUids.push(upvoterUid);
          const actorCount = actorUids.length;
          const aggregatedBody = `${actorCount} people upvoted your post`;

          await existingNotif.ref.update({
            actorUids: actorUids,
            actorCount: actorCount,
            body: aggregatedBody,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false, // Mark as unread when aggregated
          });
          await sendPushNotification(authorUid, "New Upvotes", aggregatedBody, {
            notificationType: "postUpvoted",
            targetType: "post",
            targetId: postId,
            notifId: existingNotif.id,
          });

          console.log(`✅ Aggregated upvote for post ${postId} (${actorCount} total)`);
        } else {
          console.log(`ℹ️ Upvoter ${upvoterUid} already in aggregated notification`);
        }
      } else {
        // Create new notification
        const upvoteBody = `${upvoterProfile?.nickname || "Someone"} upvoted your post`;
        const upvoteNotifId = await createNotification(authorUid, {
          type: "postUpvoted",
          actorUid: upvoterUid,
          actorNickname: upvoterProfile?.nickname || "Someone",
          actorPhotoUrl: upvoterProfile?.photoUrl,
          targetId: postId,
          targetType: "post",
          title: "New Upvote",
          body: upvoteBody,
        });
        await sendPushNotification(authorUid, "New Upvote", upvoteBody, {
          notificationType: "postUpvoted",
          targetType: "post",
          targetId: postId,
          notifId: upvoteNotifId,
        });

        console.log(`✅ Created upvote notification for post ${postId}`);
      }
    } catch (error) {
      console.error(`❌ Error in onUpvoteCreate:`, error);
      throw error;
    }
  });

// ============================================
// onCommentCreate: Comment and reply notifications
// ============================================

export const onCommentCreate = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onCreate(async (snap, context) => {
    const postId = context.params.postId as string;
    const commentId = context.params.commentId as string;
    const comment = snap.data();

    const commenterUid = comment.authorUid as string;
    const parentCommentId = comment.parentCommentId as string | undefined;

    try {
      // Fetch post to get author
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) {
        console.log(`Post ${postId} not found`);
        return;
      }

      const postData = postDoc.data()!;
      const postAuthorUid = postData.authorUid as string;
      const commenterProfile = await fetchProfile(commenterUid);

      // 1. Top-level comment → notify post author
      if (!parentCommentId) {
        // Don't notify if commenting on own post
        if (commenterUid === postAuthorUid) {
          return;
        }

        const commentBody = `${commenterProfile?.nickname || "Someone"} commented on your post`;
        const commentNotifId = await createNotification(postAuthorUid, {
          type: "postCommented",
          actorUid: commenterUid,
          actorNickname: commenterProfile?.nickname || "Someone",
          actorPhotoUrl: commenterProfile?.photoUrl,
          targetId: postId,
          targetType: "post",
          title: "New Comment",
          body: commentBody,
          metadata: {commentId: commentId},
        });
        await sendPushNotification(postAuthorUid, "New Comment", commentBody, {
          notificationType: "postCommented",
          targetType: "post",
          targetId: postId,
          notifId: commentNotifId,
        });

        console.log(`✅ Notified post author about comment on post ${postId}`);
      } else {
        // 2. Reply to comment → notify parent comment author
        const parentCommentDoc = await db
          .collection("posts")
          .doc(postId)
          .collection("comments")
          .doc(parentCommentId)
          .get();

        if (!parentCommentDoc.exists) {
          console.log(`Parent comment ${parentCommentId} not found`);
          return;
        }

        const parentCommentData = parentCommentDoc.data()!;
        const parentCommentAuthorUid = parentCommentData.authorUid as string;

        // Don't notify if replying to own comment
        if (commenterUid === parentCommentAuthorUid) {
          return;
        }

        const replyBody = `${commenterProfile?.nickname || "Someone"} replied to your comment`;
        const replyNotifId = await createNotification(parentCommentAuthorUid, {
          type: "commentReplied",
          actorUid: commenterUid,
          actorNickname: commenterProfile?.nickname || "Someone",
          actorPhotoUrl: commenterProfile?.photoUrl,
          targetId: postId,
          targetType: "post",
          title: "New Reply",
          body: replyBody,
          metadata: {commentId: commentId, parentCommentId: parentCommentId},
        });
        await sendPushNotification(parentCommentAuthorUid, "New Reply", replyBody, {
          notificationType: "commentReplied",
          targetType: "post",
          targetId: postId,
          notifId: replyNotifId,
        });

        console.log(`✅ Notified comment author about reply on post ${postId}`);
      }
    } catch (error) {
      console.error(`❌ Error in onCommentCreate:`, error);
      throw error;
    }
  });
