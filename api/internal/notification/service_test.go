package notification_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/testutil"
)

type notificationTestEnv struct {
	svc                    *notification.Service
	commentSvc             *service.CommentService
	postSvc                *service.PostService
	notificationRepository notification.NotificationStore
	userRepository         repositories.UserRepository
	postRepository         repositories.PostRepository
	commentRepository      repositories.CommentRepository
}

func setupNotificationService(t *testing.T) notificationTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	commentRepository := repositories.NewDBCommentRepository(testDb.Queries)
	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	notificationRepository := notification.NewNotificationStore(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	likeRepository := repositories.NewDBLikeRepository(testDb.Queries)
	bucketRepository := &bucket.FakeBucketRepository{}

	notificationService := notification.NewService(notificationRepository, postRepository, commentRepository, userRepository, bucketRepository)
	commentService := service.NewCommentService(commentRepository, postRepository, notificationRepository, userRepository, likeRepository, bucketRepository)
	postService := service.NewPostService(postRepository, userRepository, likeRepository, *notificationService, notificationRepository, bucketRepository, nil)

	return notificationTestEnv{
		svc:                    notificationService,
		commentSvc:             commentService,
		postSvc:                postService,
		notificationRepository: notificationRepository,
		userRepository:         userRepository,
		postRepository:         postRepository,
		commentRepository:      commentRepository,
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

func TestFindUnreadLikeNotification_PostNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	visibility := models.VisibilityPublic
	post, err := env.postRepository.InsertPost(t.Context(), user.UserID, "test post", nil, nil, &visibility)
	require.NoError(t, err)

	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, &post.PostID, nil, nil, "@user liked your post.", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	result, err := env.notificationRepository.FindUnreadLikeNotification(t.Context(), user.UserID, post.PostID, nil)
	require.NoError(t, err)
	require.NotNil(t, result)
	assert.Equal(t, "@user liked your post.", result.Message)
}

func TestFindUnreadLikeNotification_CommentNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := testutil.CreateTestUser(t, env.userRepository, "testUser")

	visibility := models.VisibilityPublic
	post, err := env.postRepository.InsertPost(t.Context(), user.UserID, "test post", nil, nil, &visibility)
	require.NoError(t, err)

	comment, err := env.commentRepository.AddCommentToPost(t.Context(), user.UserID, post.PostID, "test comment", nil)
	require.NoError(t, err)

	_, err = env.notificationRepository.InsertNotification(t.Context(), user.UserID, &post.PostID, &comment.CommentID, nil, "@user liked your comment.", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	result, err := env.notificationRepository.FindUnreadLikeNotification(t.Context(), user.UserID, post.PostID, &comment.CommentID)
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

func TestAddLikeNotification_IsWorking(t *testing.T) {
	env := setupNotificationService(t)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "user0")
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

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should still have 1 unread notification")

	assert.Equal(t, "@liker1 and @liker0 liked your post.", notifications[0].Message)

	expectedFacets, err := repositories.GenerateFacets(t.Context(), env.userRepository, notifications[0].Message)
	require.NoError(t, err)
	assert.Equal(t, expectedFacets, notifications[0].Facets)

	liker2 := testutil.CreateTestUser(t, env.userRepository, "liker2")
	err = env.svc.AddLikeNotification(t.Context(), liker2.UserID, post.PostID, nil)
	require.NoError(t, err)

	notifications, err = env.svc.GetUnreadNotificationsByUserIdWithTimeOffset(t.Context(), postOwner, time.Now().UTC(), 10, nil)
	require.NoError(t, err)
	require.Len(t, notifications, 1, "poster should still have 1 unread notification")

	assert.Equal(t, "@liker2, @liker1, and @liker0 liked your post.", notifications[0].Message)
}

func TestAddLikeNotification_HandlesRemovedLikes(t *testing.T) {
	env := setupNotificationService(t)

	postOwner := testutil.CreateTestUser(t, env.userRepository, "user0")
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
