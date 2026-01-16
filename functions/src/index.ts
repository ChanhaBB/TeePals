import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

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

// Helper: Create notification
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
): Promise<void> {
  try {
    await db
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

        await createNotification(hostUid, {
          type: "roundJoinRequest",
          actorUid: memberUid,
          actorNickname: requesterProfile?.nickname || "Someone",
          actorPhotoUrl: requesterProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Join Request",
          body: `${requesterProfile?.nickname || "Someone"} requested to join your round`,
          metadata: {
            roundName: courseName,
            roundDate: roundDate,
          },
        });
      }

      // 2. Request accepted → notify member
      if (before?.status === "requested" && after.status === "accepted") {
        const hostProfile = await fetchProfile(hostUid);

        await createNotification(memberUid, {
          type: "roundJoinAccepted",
          actorUid: hostUid,
          actorNickname: hostProfile?.nickname || "Host",
          actorPhotoUrl: hostProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Request Accepted",
          body: `Your request to join the round was accepted`,
          metadata: {
            roundName: courseName,
            roundDate: roundDate,
          },
        });
      }

      // 3. Request declined → notify member
      if (before?.status === "requested" && after.status === "declined") {
        const hostProfile = await fetchProfile(hostUid);

        await createNotification(memberUid, {
          type: "roundJoinDeclined",
          actorUid: hostUid,
          actorNickname: hostProfile?.nickname || "Host",
          actorPhotoUrl: hostProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Request Declined",
          body: `Your request to join the round was declined`,
          metadata: {
            roundName: courseName,
          },
        });
      }

      // 4. User invited → notify invitee
      // Trigger on: first invite OR re-invite after decline/left/removal
      if ((!before || before.status === "declined" || before.status === "left" || before.status === "removed") && after.status === "invited") {
        const inviterUid = after.invitedBy as string;
        const inviterProfile = await fetchProfile(inviterUid);

        await createNotification(memberUid, {
          type: "roundInvitation",
          actorUid: inviterUid,
          actorNickname: inviterProfile?.nickname || "Someone",
          actorPhotoUrl: inviterProfile?.photoUrl,
          targetId: roundId,
          targetType: "round",
          title: "Round Invitation",
          body: `${inviterProfile?.nickname || "Someone"} invited you to a round`,
          metadata: {
            roundName: courseName,
            roundDate: roundDate,
          },
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

        if (!existingNotifsSnapshot.empty) {
          // Update existing notification with latest message
          const existingNotif = existingNotifsSnapshot.docs[0];
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
          await db
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

          console.log(`✅ Created chat notification for ${memberUid} in round ${roundId}`);
        }
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

          await createNotification(memberUid, {
            type: "roundCancelled",
            actorUid: after.hostUid,
            actorNickname: hostProfile?.nickname || "Host",
            actorPhotoUrl: hostProfile?.photoUrl,
            targetId: roundId,
            targetType: "round",
            title: "Round Canceled",
            body: `${courseName} on ${roundDate} has been canceled`,
            metadata: {
              roundName: courseName,
              roundDate: roundDate,
            },
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

          await createNotification(memberUid, {
            type: "roundUpdated",
            actorUid: after.hostUid,
            actorNickname: hostProfile?.nickname || "Host",
            actorPhotoUrl: hostProfile?.photoUrl,
            targetId: roundId,
            targetType: "round",
            title: "Round Updated",
            body: `${updateDescription} for ${courseName} on ${roundDate}`,
            metadata: {
              roundName: courseName,
              roundDate: roundDate,
            },
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

        await createNotification(memberUid, {
          type: "feedbackReminder",
          targetId: roundId,
          targetType: "round",
          title: "Rate your playing partners",
          body: `You played at ${courseName}. Share your experience!`,
          metadata: {
            courseName: courseName,
          },
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

      await createNotification(userId, {
        type: "userFollowed",
        actorUid: followerId,
        actorNickname: followerProfile?.nickname || "Someone",
        actorPhotoUrl: followerProfile?.photoUrl,
        targetId: followerId,
        targetType: "profile",
        title: "New Follower",
        body: `${followerProfile?.nickname || "Someone"} started following you`,
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

          await existingNotif.ref.update({
            actorUids: actorUids,
            actorCount: actorCount,
            body: `${actorCount} people upvoted your post`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false, // Mark as unread when aggregated
          });

          console.log(`✅ Aggregated upvote for post ${postId} (${actorCount} total)`);
        } else {
          console.log(`ℹ️ Upvoter ${upvoterUid} already in aggregated notification`);
        }
      } else {
        // Create new notification
        await createNotification(authorUid, {
          type: "postUpvoted",
          actorUid: upvoterUid,
          actorNickname: upvoterProfile?.nickname || "Someone",
          actorPhotoUrl: upvoterProfile?.photoUrl,
          targetId: postId,
          targetType: "post",
          title: "New Upvote",
          body: `${upvoterProfile?.nickname || "Someone"} upvoted your post`,
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

        await createNotification(postAuthorUid, {
          type: "postCommented",
          actorUid: commenterUid,
          actorNickname: commenterProfile?.nickname || "Someone",
          actorPhotoUrl: commenterProfile?.photoUrl,
          targetId: postId,
          targetType: "post",
          title: "New Comment",
          body: `${commenterProfile?.nickname || "Someone"} commented on your post`,
          metadata: {
            commentId: commentId,
          },
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

        await createNotification(parentCommentAuthorUid, {
          type: "commentReplied",
          actorUid: commenterUid,
          actorNickname: commenterProfile?.nickname || "Someone",
          actorPhotoUrl: commenterProfile?.photoUrl,
          targetId: postId,
          targetType: "post",
          title: "New Reply",
          body: `${commenterProfile?.nickname || "Someone"} replied to your comment`,
          metadata: {
            commentId: commentId,
            parentCommentId: parentCommentId,
          },
        });

        console.log(`✅ Notified comment author about reply on post ${postId}`);
      }
    } catch (error) {
      console.error(`❌ Error in onCommentCreate:`, error);
      throw error;
    }
  });
