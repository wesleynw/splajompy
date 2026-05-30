package notification_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/comment"
	db "splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/testutil"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"
)

type notificationTestEnv struct {
	svc                    *notification.Service
	commentSvc             *comment.Service
	postSvc                *post.Service
	notificationRepository notification.Store
	userRepository         user.Store
	postRepository         post.Store
	commentRepository      comment.Store
}

func setupNotificationService(t *testing.T) notificationTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)

	notificationService := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	commentService := comment.NewService(&db.CommentRepository, db.PostRepository, *notificationService, db.UserRepository, db.LikeRepository, db.BucketRepository)
	postService := post.NewService(db.PostRepository, db.UserRepository, db.LikeRepository, *notificationService, db.BucketRepository, nil)

	return notificationTestEnv{
		svc:                    notificationService,
		commentSvc:             commentService,
		postSvc:                postService,
		notificationRepository: db.NotificationStore,
		userRepository:         db.UserRepository,
		postRepository:         db.PostRepository,
		commentRepository:      db.CommentRepository,
	}
}

func TestMarkNotificationAsReadById(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	_, err := env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	hasUnread, err := env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	dbNotifications, err := env.notificationRepository.GetNotificationsForUserId(t.Context(), user.UserID, 0, 10)
	require.NoError(t, err)
	require.Len(t, dbNotifications, 1)
	notificationId := dbNotifications[0].NotificationID

	err = env.svc.MarkNotificationAsReadById(t.Context(), user, notificationId)
	require.NoError(t, err)

	notifications, err := env.svc.GetReadNotificationsByUserIdWithTimeOffset(t.Context(), user, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	require.Len(t, notifications, 1)
	assert.True(t, notifications[0].Viewed)
}

func TestMarkAllNotificationsAsReadForUserId(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	_, err := env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 1", models.NotificationTypeLike, nil)
	require.NoError(t, err)
	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 2", models.NotificationTypeLike, nil)
	require.NoError(t, err)
	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 3", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	hasUnread, err := env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	err = env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), user)
	require.NoError(t, err)

	notifications, err := env.svc.GetReadNotificationsByUserIdWithTimeOffset(t.Context(), user, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 3)

	for _, notification := range notifications {
		assert.True(t, notification.Viewed, "Notification should be marked as read")
	}

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)
}

func TestUserHasUnreadNotifications(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	hasUnread, err := env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)

	// Insert then immediately mark read to simulate a pre-read notification
	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Read notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)
	require.NoError(t, env.notificationRepository.MarkAllNotificationsAsReadForUser(t.Context(), user.UserID))

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)

	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Unread notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	err = env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), user)
	require.NoError(t, err)

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)
}

func TestErrorWhenMarkingNonExistentNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	err := env.svc.MarkNotificationAsReadById(t.Context(), user, 999)
	assert.Error(t, err)
}

func TestGetUserUnreadNotificationsCount(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	// Insert 2 notifications and mark them read, then insert 1 unread
	_, err := env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Notification 1", models.NotificationTypeLike, nil)
	require.NoError(t, err)
	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Notification 2", models.NotificationTypeLike, nil)
	require.NoError(t, err)
	require.NoError(t, env.notificationRepository.MarkAllNotificationsAsReadForUser(t.Context(), user.UserID))
	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Unread notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	count, err := env.svc.GetUserUnreadNotificationCount(t.Context(), user)
	require.NoError(t, err)
	assert.Equal(t, 1, count)
}

func TestFindLikeNotification_PostNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	visibility := models.VisibilityPublic
	post, err := env.postRepository.InsertPost(t.Context(), user.UserID, "test post", nil, nil, &visibility)
	require.NoError(t, err)

	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, &post.PostID, nil, nil, "@user liked your post.", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	result, err := env.notificationRepository.FindLikeNotification(t.Context(), user.UserID, post.PostID, nil)
	require.NoError(t, err)
	require.NotNil(t, result)
	assert.Equal(t, "@user liked your post.", result.Message)
}

func TestFindLikeNotification_CommentNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	visibility := models.VisibilityPublic
	post, err := env.postRepository.InsertPost(t.Context(), user.UserID, "test post", nil, nil, &visibility)
	require.NoError(t, err)

	comment, err := env.commentRepository.AddCommentToPost(t.Context(), user.UserID, post.PostID, "test comment", nil)
	require.NoError(t, err)

	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, &post.PostID, &comment.CommentID, nil, "@user liked your comment.", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	result, err := env.notificationRepository.FindLikeNotification(t.Context(), user.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)
	require.NotNil(t, result)
	assert.Equal(t, "@user liked your comment.", result.Message)
}

func TestDeleteNotificationById_Success(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	_, err := env.notificationRepository.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	notifications, err := env.notificationRepository.GetNotificationsForUserId(t.Context(), user.UserID, 0, 10)
	require.NoError(t, err)
	require.Len(t, notifications, 1)

	err = env.notificationRepository.DeleteNotificationById(t.Context(), notifications[0].NotificationID)
	require.NoError(t, err)

	notifications, err = env.notificationRepository.GetNotificationsForUserId(t.Context(), user.UserID, 0, 10)
	require.NoError(t, err)
	assert.Len(t, notifications, 0)
}

func TestGetComments_DoesNotFailLinkingToDeletedUsers(t *testing.T) {
	env := setupNotificationService(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	_, err := env.notificationRepository.InsertNotification(t.Context(), user0.UserID, nil, nil, nil, "test notification", models.NotificationTypeLike, &user1.UserID)
	require.NoError(t, err)

	err = env.userRepository.DeleteAccount(t.Context(), user1.UserID)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), user0, time.Now().UTC(), 10, nil)
	assert.NoError(t, err)
	assert.Len(t, notifications, 1)

	err = env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), user0)
	require.NoError(t, err)

	notifications, err = env.svc.GetReadNotificationsByUserIdWithTimeOffset(t.Context(), user0, time.Now().UTC(), 10, nil)
	assert.NoError(t, err)
	assert.Len(t, notifications, 1)
}

func TestCommentNotification_ImagePopulatedFromComment(t *testing.T) {
	env := setupNotificationService(t)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "postOwner")
	commenter := testutil.CreateTestUser(t, env.userRepository, "commenter")

	visibility := models.VisibilityPublic
	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, &visibility)
	require.NoError(t, err)

	imageKey := "images/test-image.jpg"
	imageKeyMap := map[int]models.ImageData{
		0: {S3Key: imageKey, Width: 640, Height: 480},
	}
	_, err = env.commentSvc.AddCommentToPost(t.Context(), commenter, post.PostID, "test comment with image", imageKeyMap)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	require.NotNil(t, notifications[0].ImageBlob, "imageBlob should be set from the comment image")
	assert.Equal(t, imageKey, *notifications[0].ImageBlob)
	assert.Equal(t, 640, *notifications[0].ImageWidth)
	assert.Equal(t, 480, *notifications[0].ImageHeight)

	unread, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, unread, 1)
	require.NotNil(t, unread[0].ImageBlob)
	assert.Equal(t, imageKey, *unread[0].ImageBlob)

	require.NoError(t, env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), postOwner))

	read, err := env.svc.GetReadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, read, 1)
	require.NotNil(t, read[0].ImageBlob)
	assert.Equal(t, imageKey, *read[0].ImageBlob)
}

func TestGetNotifications_MentionUserInUnreachablePost(t *testing.T) {
	env := setupNotificationService(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	_, err := env.postSvc.NewPost(t.Context(), user0, "hello @user1", nil, nil, new(int(models.VisibilityCloseFriends)))
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), user1, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Empty(t, notifications)
}

func TestGetNotifications_MentionUserInNewlyUnreachablePost(t *testing.T) {
	env := setupNotificationService(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	err := env.userRepository.AddUserRelationship(t.Context(), user0.UserID, user1.UserID)
	require.NoError(t, err)

	_, err = env.postSvc.NewPost(t.Context(), user0, "hello @user1", nil, nil, new(int(models.VisibilityCloseFriends)))
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), user1, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Len(t, notifications, 1)

	err = env.userRepository.RemoveUserRelationship(t.Context(), user0.UserID, user1.UserID)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), user1, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Empty(t, notifications)
}

func TestAddLikeNotification_MultipleNotificationsCombine(t *testing.T) {
	env := setupNotificationService(t)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "user0")
	appVersion := "v1.8.2"
	err := env.userRepository.UpdateUserDisplayProperties(t.Context(), postOwner.UserID, &db.UserDisplayProperties{LatestAppVersion: &appVersion})
	require.NoError(t, err)

	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	liker0 := testutil.CreateTestUser(t, env.userRepository, "liker0")
	err = env.svc.AddLikeNotification(t.Context(), liker0.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should have 1 unread notification")

	liker1 := testutil.CreateTestUser(t, env.userRepository, "liker1")
	err = env.svc.AddLikeNotification(t.Context(), liker1.UserID, post.PostID, nil)
	require.NoError(t, err)

	originalCommentTimestamp := notifications[0].CreatedAt

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should still have 1 unread notification")

	assert.Equal(t, "@liker1 and @liker0 liked your post.", notifications[0].Message)
	assert.Greater(t, notifications[0].CreatedAt, originalCommentTimestamp)

	expectedFacets, err := utilities.GenerateFacets(t.Context(), env.userRepository, notifications[0].Message)
	require.NoError(t, err)
	assert.Equal(t, expectedFacets, notifications[0].Facets)

	liker2 := testutil.CreateTestUser(t, env.userRepository, "liker2")
	err = env.svc.AddLikeNotification(t.Context(), liker2.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should still have 1 unread notification")

	assert.Equal(t, "@liker2, @liker1, and @liker0 liked your post.", notifications[0].Message)

	liker3 := testutil.CreateTestUser(t, env.userRepository, "liker3")

	err = env.svc.AddLikeNotification(t.Context(), liker3.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should still have 1 unread notification")

	assert.Equal(t, "@liker3, @liker2, @liker1, and others liked your post.", notifications[0].Message)

	// set to incompatible version
	ctx := context.WithValue(t.Context(), utilities.AppVersionKey, "v1.0.0")

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(ctx, postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should still have 1 unread notification")

	assert.Equal(t, "@liker3, @liker2, @liker1, and others liked your post.", notifications[0].Message)
}

func TestAddLikeNotification_HandlesRemovedLikes(t *testing.T) {
	env := setupNotificationService(t)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "user0")
	appVersion := "v1.8.2"
	err := env.userRepository.UpdateUserDisplayProperties(t.Context(), postOwner.UserID, &db.UserDisplayProperties{LatestAppVersion: &appVersion})
	require.NoError(t, err)

	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	liker0 := testutil.CreateTestUser(t, env.userRepository, "liker0")
	err = env.svc.AddLikeNotification(t.Context(), liker0.UserID, post.PostID, nil)
	require.NoError(t, err)

	liker1 := testutil.CreateTestUser(t, env.userRepository, "liker1")
	err = env.svc.AddLikeNotification(t.Context(), liker1.UserID, post.PostID, nil)
	require.NoError(t, err)

	liker2 := testutil.CreateTestUser(t, env.userRepository, "liker2")
	err = env.svc.AddLikeNotification(t.Context(), liker2.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "@liker2, @liker1, and @liker0 liked your post.", notifications[0].Message)

	err = env.svc.RemoveLikeNotification(t.Context(), liker2.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "@liker1 and @liker0 liked your post.", notifications[0].Message)

	err = env.svc.RemoveLikeNotification(t.Context(), liker1.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "@liker0 liked your post.", notifications[0].Message)

	err = env.svc.RemoveLikeNotification(t.Context(), liker0.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 0)
}

func TestRemoveLikeNotification_WithSelfLikes(t *testing.T) {
	env := setupNotificationService(t)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "user0")
	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	err = env.svc.AddLikeNotification(t.Context(), postOwner.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Empty(t, notifications)

	liker0 := testutil.CreateTestUser(t, env.userRepository, "liker0")
	err = env.svc.AddLikeNotification(t.Context(), liker0.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "@liker0 liked your post.", notifications[0].Message)

	err = env.svc.RemoveLikeNotification(t.Context(), liker0.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Empty(t, notifications)
}

func TestAddLikeNotification_Comment_MultipleNotificationsCombine(t *testing.T) {
	env := setupNotificationService(t)

	commenter := testutil.CreateTestUser(t, env.userRepository, "commenter")
	appVersion := "v1.8.2"
	err := env.userRepository.UpdateUserDisplayProperties(t.Context(), commenter.UserID, &db.UserDisplayProperties{LatestAppVersion: &appVersion})
	require.NoError(t, err)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "postOwner")
	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := env.commentRepository.AddCommentToPost(t.Context(), commenter.UserID, post.PostID, "test comment", nil)
	require.NoError(t, err)

	liker0 := testutil.CreateTestUser(t, env.userRepository, "liker0")
	err = env.svc.AddLikeNotification(t.Context(), liker0.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "commenter should have 1 unread notification")
	assert.Equal(t, "@liker0 liked your comment.", notifications[0].Message)

	liker1 := testutil.CreateTestUser(t, env.userRepository, "liker1")
	err = env.svc.AddLikeNotification(t.Context(), liker1.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "commenter should still have 1 unread notification after second like")
	assert.Equal(t, "@liker1 and @liker0 liked your comment.", notifications[0].Message)

	liker2 := testutil.CreateTestUser(t, env.userRepository, "liker2")
	err = env.svc.AddLikeNotification(t.Context(), liker2.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "commenter should still have 1 unread notification after third like")
	assert.Equal(t, "@liker2, @liker1, and @liker0 liked your comment.", notifications[0].Message)
}

func TestAddLikeNotification_Comment_HandlesRemovedLikes(t *testing.T) {
	env := setupNotificationService(t)

	commenter := testutil.CreateTestUser(t, env.userRepository, "commenter")
	appVersion := "v1.8.2"
	err := env.userRepository.UpdateUserDisplayProperties(t.Context(), commenter.UserID, &db.UserDisplayProperties{LatestAppVersion: &appVersion})
	require.NoError(t, err)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "postOwner")
	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := env.commentRepository.AddCommentToPost(t.Context(), commenter.UserID, post.PostID, "test comment", nil)
	require.NoError(t, err)

	liker0 := testutil.CreateTestUser(t, env.userRepository, "liker0")
	err = env.svc.AddLikeNotification(t.Context(), liker0.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	liker1 := testutil.CreateTestUser(t, env.userRepository, "liker1")
	err = env.svc.AddLikeNotification(t.Context(), liker1.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "@liker1 and @liker0 liked your comment.", notifications[0].Message)

	err = env.svc.RemoveLikeNotification(t.Context(), liker1.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "@liker0 liked your comment.", notifications[0].Message)

	err = env.svc.RemoveLikeNotification(t.Context(), liker0.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Empty(t, notifications)
}

func TestAddLikeNotification_Comment_SelfLikeIgnored(t *testing.T) {
	env := setupNotificationService(t)

	commenter := testutil.CreateTestUser(t, env.userRepository, "commenter")
	postOwner := testutil.CreateTestUser(t, env.userRepository, "postOwner")
	post, err := env.postRepository.InsertPost(t.Context(), postOwner.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := env.commentRepository.AddCommentToPost(t.Context(), commenter.UserID, post.PostID, "test comment", nil)
	require.NoError(t, err)

	err = env.svc.AddLikeNotification(t.Context(), commenter.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)

	notifications, err := env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), commenter, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	assert.Empty(t, notifications, "commenter liking their own comment should not create a notification")
}

func TestRegisterDeviceToken_UpdatesOldToken(t *testing.T) {
	env := setupNotificationService(t)

	user := testutil.CreateTestUser(t, env.userRepository, "user0")
	err := env.svc.RegisterDevice(t.Context(), user.UserID, "abc123", false, false, false)
	require.NoError(t, err)

	err = env.svc.RegisterDevice(t.Context(), user.UserID, "def456", false, false, false)
	require.NoError(t, err)

	devices, err := env.notificationRepository.GetDeviceTokensForUser(t.Context(), user.UserID)
	require.NoError(t, err)

	tokens := make([]string, len(devices))
	for i, d := range devices {
		tokens[i] = d.Token
	}
	assert.Contains(t, tokens, "def456")
}

func TestRegisterDevice_UpdatePreferences(t *testing.T) {
	env := setupNotificationService(t)

	user := testutil.CreateTestUser(t, env.userRepository, "user0")
	err := env.svc.RegisterDevice(t.Context(), user.UserID, "abc123", true, true, false)
	require.NoError(t, err)

	err = env.svc.RegisterDevice(t.Context(), user.UserID, "abc123", false, false, true)
	require.NoError(t, err)

	tokens, err := env.notificationRepository.GetDeviceTokensForUser(t.Context(), user.UserID)
	require.NoError(t, err)
	require.Len(t, tokens, 1)

	device := tokens[0]
	assert.False(t, device.IsEnabledMentions)
	assert.False(t, device.IsEnabledComments)
	assert.True(t, device.IsEnabledFollows)
}
