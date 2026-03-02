package service

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/testutil"
)

type notificationTestEnv struct {
	svc         NotificationService
	notifRepo   repositories.NotificationRepository
	userRepo    repositories.UserRepository
	postRepo    repositories.PostRepository
	commentRepo repositories.CommentRepository
}

func setupNotificationService(t *testing.T) notificationTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	commentRepository := repositories.NewDBCommentRepository(testDb.Queries)
	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	notificationRepository := repositories.NewDBNotificationRepository(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)

	notificationService := NewNotificationService(notificationRepository, postRepository, commentRepository, userRepository)

	return notificationTestEnv{
		svc:         *notificationService,
		notifRepo:   notificationRepository,
		userRepo:    userRepository,
		postRepo:    postRepository,
		commentRepo: commentRepository,
	}
}

func insertTestUser(t *testing.T, userRepo repositories.UserRepository, username, email string) models.PublicUser {
	t.Helper()
	user, err := userRepo.CreateUser(t.Context(), username, email, "password123", "ref-"+username)
	require.NoError(t, err)
	return user
}

func TestGetNotificationsByUserId(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	notifications, err := env.svc.GetNotificationsByUserId(t.Context(), user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 0)

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 1", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 2", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 3", models.NotificationTypeLike, nil))

	notifications, err = env.svc.GetNotificationsByUserId(t.Context(), user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 3)

	notifications, err = env.svc.GetNotificationsByUserId(t.Context(), user, 0, 2)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 2)

	notifications, err = env.svc.GetNotificationsByUserId(t.Context(), user, 2, 2)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 1)

	notifications, err = env.svc.GetNotificationsByUserId(t.Context(), user, 5, 2)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 0)

	anotherUser := insertTestUser(t, env.userRepo, "anotherUser", "another@example.com")

	notifications, err = env.svc.GetNotificationsByUserId(t.Context(), anotherUser, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 0)
}

func TestMarkNotificationAsReadById(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification", models.NotificationTypeLike, nil))

	hasUnread, err := env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	dbNotifications, err := env.notifRepo.GetNotificationsForUserId(t.Context(), user.UserID, 0, 10)
	require.NoError(t, err)
	require.Len(t, dbNotifications, 1)
	notificationId := dbNotifications[0].NotificationID

	err = env.svc.MarkNotificationAsReadById(t.Context(), user, notificationId)
	require.NoError(t, err)

	notifications, err := env.svc.GetNotificationsByUserId(t.Context(), user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, notifications, 1)
	assert.True(t, notifications[0].Viewed)
}

func TestMarkAllNotificationsAsReadForUserId(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 1", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 2", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification 3", models.NotificationTypeLike, nil))

	hasUnread, err := env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	err = env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), user)
	require.NoError(t, err)

	notifications, err := env.svc.GetNotificationsByUserId(t.Context(), user, 0, 10)
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
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	hasUnread, err := env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)

	// Insert then immediately mark read to simulate a pre-read notification
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Read notification", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.MarkAllNotificationsAsReadForUser(t.Context(), user.UserID))

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Unread notification", models.NotificationTypeLike, nil))

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	err = env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), user)
	require.NoError(t, err)

	hasUnread, err = env.svc.UserHasUnreadNotifications(t.Context(), user)
	require.NoError(t, err)
	assert.False(t, hasUnread)
}

func TestMultipleUsersNotifications(t *testing.T) {
	env := setupNotificationService(t)

	user1 := insertTestUser(t, env.userRepo, "user1", "user1@example.com")
	user2 := insertTestUser(t, env.userRepo, "user2", "user2@example.com")

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user1.UserID, nil, nil, nil, "User 1 notification 1", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user1.UserID, nil, nil, nil, "User 1 notification 2", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user2.UserID, nil, nil, nil, "User 2 notification 1", models.NotificationTypeLike, nil))

	notificationsUser1, err := env.svc.GetNotificationsByUserId(t.Context(), user1, 0, 10)
	require.NoError(t, err)
	assert.Len(t, notificationsUser1, 2)

	notificationsUser2, err := env.svc.GetNotificationsByUserId(t.Context(), user2, 0, 10)
	require.NoError(t, err)
	assert.Len(t, notificationsUser2, 1)

	err = env.svc.MarkAllNotificationsAsReadForUserId(t.Context(), user1)
	require.NoError(t, err)

	hasUnreadUser1, err := env.svc.UserHasUnreadNotifications(t.Context(), user1)
	require.NoError(t, err)
	assert.False(t, hasUnreadUser1)

	hasUnreadUser2, err := env.svc.UserHasUnreadNotifications(t.Context(), user2)
	require.NoError(t, err)
	assert.True(t, hasUnreadUser2)
}

func TestNoErrorWhenMarkingNonExistentNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	err := env.svc.MarkNotificationAsReadById(t.Context(), user, 999)
	assert.Error(t, err)
}

func TestGetUserUnreadNotificationsCount(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	// Insert 2 notifications and mark them read, then insert 1 unread
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Notification 1", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Notification 2", models.NotificationTypeLike, nil))
	require.NoError(t, env.notifRepo.MarkAllNotificationsAsReadForUser(t.Context(), user.UserID))
	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Unread notification", models.NotificationTypeLike, nil))

	count, err := env.svc.GetUserUnreadNotificationCount(t.Context(), user)
	require.NoError(t, err)
	assert.Equal(t, 1, count)
}

func TestFindUnreadLikeNotification_PostNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	post, err := env.postRepo.InsertPost(t.Context(), user.UserID, "test post", nil, nil, nil)
	require.NoError(t, err)

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, &post.PostID, nil, nil, "@user liked your post.", models.NotificationTypeLike, nil))

	result, err := env.notifRepo.FindUnreadLikeNotification(t.Context(), user.UserID, post.PostID, nil)
	require.NoError(t, err)
	require.NotNil(t, result)
	assert.Equal(t, "@user liked your post.", result.Message)
}

func TestFindUnreadLikeNotification_CommentNotification(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	post, err := env.postRepo.InsertPost(t.Context(), user.UserID, "test post", nil, nil, nil)
	require.NoError(t, err)

	comment, err := env.commentRepo.AddCommentToPost(t.Context(), user.UserID, post.PostID, "test comment", nil)
	require.NoError(t, err)

	require.NoError(t, env.notifRepo.InsertNotification(t.Context(), user.UserID, &post.PostID, &comment.CommentID, nil, "@user liked your comment.", models.NotificationTypeLike, nil))

	result, err := env.notifRepo.FindUnreadLikeNotification(t.Context(), user.UserID, post.PostID, &comment.CommentID)
	require.NoError(t, err)
	require.NotNil(t, result)
	assert.Equal(t, "@user liked your comment.", result.Message)
}

func TestDeleteNotificationById_Success(t *testing.T) {
	env := setupNotificationService(t)
	user := insertTestUser(t, env.userRepo, "testUser", "test@example.com")

	err := env.notifRepo.InsertNotification(t.Context(), user.UserID, nil, nil, nil, "Test notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	notifications, err := env.notifRepo.GetNotificationsForUserId(t.Context(), user.UserID, 0, 10)
	require.NoError(t, err)
	require.Len(t, notifications, 1)

	err = env.notifRepo.DeleteNotificationById(t.Context(), notifications[0].NotificationID)
	require.NoError(t, err)

	notifications, err = env.notifRepo.GetNotificationsForUserId(t.Context(), user.UserID, 0, 10)
	require.NoError(t, err)
	assert.Len(t, notifications, 0)
}
