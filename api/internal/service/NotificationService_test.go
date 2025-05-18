package service

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories/fakes"
	"testing"
	"time"
)

func setupNotificationService() (*NotificationService, *fakes.FakeNotificationRepository) {
	fakeRepo := fakes.NewFakeNotificationRepository()
	notificationService := NewNotificationService(fakeRepo)
	return notificationService, fakeRepo
}

func createTestUser() models.PublicUser {
	return models.PublicUser{
		UserID:    1,
		Email:     "test@example.com",
		Username:  "testuser",
		CreatedAt: pgtype.Timestamp{Time: time.Now(), Valid: true},
		Name:      pgtype.Text{String: "Test User", Valid: true},
	}
}

func createTestNotification(userID int, notificationID int, message string, viewed bool) queries.Notification {
	return queries.Notification{
		NotificationID: int32(notificationID),
		UserID:         int32(userID),
		PostID:         pgtype.Int4{Int32: 0, Valid: false},
		Message:        message,
		Viewed:         viewed,
		CreatedAt:      pgtype.Timestamp{Time: time.Now(), Valid: true},
	}
}

func TestGetNotificationsByUserId(t *testing.T) {
	ctx := context.Background()
	service, fakeRepo := setupNotificationService()
	user := createTestUser()
	userId := int(user.UserID)

	notifications, err := service.GetNotificationsByUserId(ctx, user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 0)

	fakeRepo.AddNotification(createTestNotification(userId, 1, "Test notification 1", false))
	fakeRepo.AddNotification(createTestNotification(userId, 2, "Test notification 2", false))
	fakeRepo.AddNotification(createTestNotification(userId, 3, "Test notification 3", true))

	notifications, err = service.GetNotificationsByUserId(ctx, user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 3)

	notifications, err = service.GetNotificationsByUserId(ctx, user, 0, 2)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 2)

	notifications, err = service.GetNotificationsByUserId(ctx, user, 2, 2)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 1)

	notifications, err = service.GetNotificationsByUserId(ctx, user, 5, 2)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 0)

	anotherUser := models.PublicUser{
		UserID:    2,
		Email:     "another@example.com",
		Username:  "anotheruser",
		CreatedAt: pgtype.Timestamp{Time: time.Now(), Valid: true},
		Name:      pgtype.Text{String: "Another User", Valid: true},
	}

	notifications, err = service.GetNotificationsByUserId(ctx, anotherUser, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 0)
}

func TestMarkNotificationAsReadById(t *testing.T) {
	ctx := context.Background()
	service, fakeRepo := setupNotificationService()
	user := createTestUser()
	userId := int(user.UserID)

	notification := createTestNotification(userId, 1, "Test notification", false)
	fakeRepo.AddNotification(notification)

	hasUnread, err := service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	notificationId := int(notification.NotificationID)

	err = service.MarkNotificationAsReadById(ctx, user, notificationId)

	require.NoError(t, err)

	notifications, err := service.GetNotificationsByUserId(ctx, user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 1)

	assert.True(t, (*notifications)[0].Viewed)
}

func TestMarkAllNotificationsAsReadForUserId(t *testing.T) {
	ctx := context.Background()
	service, fakeRepo := setupNotificationService()
	user := createTestUser()
	userId := int(user.UserID)

	fakeRepo.AddNotification(createTestNotification(userId, 1, "Test notification 1", false))
	fakeRepo.AddNotification(createTestNotification(userId, 2, "Test notification 2", false))
	fakeRepo.AddNotification(createTestNotification(userId, 3, "Test notification 3", false))

	hasUnread, err := service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	err = service.MarkAllNotificationsAsReadForUserId(ctx, user)
	require.NoError(t, err)

	notifications, err := service.GetNotificationsByUserId(ctx, user, 0, 10)
	require.NoError(t, err)
	assert.NotNil(t, notifications)
	assert.Len(t, *notifications, 3)

	for _, notification := range *notifications {
		assert.True(t, notification.Viewed, "Notification should be marked as read")
	}

	hasUnread, err = service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.False(t, hasUnread)
}

func TestUserHasUnreadNotifications(t *testing.T) {

	ctx := context.Background()
	service, fakeRepo := setupNotificationService()
	user := createTestUser()
	userId := int(user.UserID)

	hasUnread, err := service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.False(t, hasUnread)

	fakeRepo.AddNotification(createTestNotification(userId, 1, "Read notification", true))

	hasUnread, err = service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.False(t, hasUnread)

	fakeRepo.AddNotification(createTestNotification(userId, 2, "Unread notification", false))

	hasUnread, err = service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.True(t, hasUnread)

	err = service.MarkAllNotificationsAsReadForUserId(ctx, user)
	require.NoError(t, err)

	hasUnread, err = service.UserHasUnreadNotifications(ctx, user)
	require.NoError(t, err)
	assert.False(t, hasUnread)
}

func TestMultipleUsersNotifications(t *testing.T) {
	ctx := context.Background()
	service, fakeRepo := setupNotificationService()

	user1 := models.PublicUser{
		UserID:    1,
		Email:     "user1@example.com",
		Username:  "user1",
		CreatedAt: pgtype.Timestamp{Time: time.Now(), Valid: true},
		Name:      pgtype.Text{String: "User One", Valid: true},
	}

	user2 := models.PublicUser{
		UserID:    2,
		Email:     "user2@example.com",
		Username:  "user2",
		CreatedAt: pgtype.Timestamp{Time: time.Now(), Valid: true},
		Name:      pgtype.Text{String: "User Two", Valid: true},
	}

	fakeRepo.AddNotification(createTestNotification(int(user1.UserID), 1, "User 1 notification 1", false))
	fakeRepo.AddNotification(createTestNotification(int(user1.UserID), 2, "User 1 notification 2", false))
	fakeRepo.AddNotification(createTestNotification(int(user2.UserID), 3, "User 2 notification 1", false))

	notificationsUser1, err := service.GetNotificationsByUserId(ctx, user1, 0, 10)
	require.NoError(t, err)
	assert.Len(t, *notificationsUser1, 2)

	notificationsUser2, err := service.GetNotificationsByUserId(ctx, user2, 0, 10)
	require.NoError(t, err)
	assert.Len(t, *notificationsUser2, 1)

	err = service.MarkAllNotificationsAsReadForUserId(ctx, user1)
	require.NoError(t, err)

	hasUnreadUser1, err := service.UserHasUnreadNotifications(ctx, user1)
	require.NoError(t, err)
	assert.False(t, hasUnreadUser1)

	hasUnreadUser2, err := service.UserHasUnreadNotifications(ctx, user2)
	require.NoError(t, err)
	assert.True(t, hasUnreadUser2)
}

func TestNotificationWithPostInfo(t *testing.T) {
	ctx := context.Background()
	service, fakeRepo := setupNotificationService()
	user := createTestUser()
	userId := int(user.UserID)

	postId := 123
	notification := queries.Notification{
		NotificationID: 1,
		UserID:         int32(userId),
		PostID:         pgtype.Int4{Int32: int32(postId), Valid: true},
		Message:        "Someone commented on your post",
		Viewed:         false,
		CreatedAt:      pgtype.Timestamp{Time: time.Now(), Valid: true},
	}

	fakeRepo.AddNotification(notification)

	notifications, err := service.GetNotificationsByUserId(ctx, user, 0, 10)
	require.NoError(t, err)
	assert.Len(t, *notifications, 1)

	retrievedNotification := (*notifications)[0]
	assert.True(t, retrievedNotification.PostID.Valid)
	assert.Equal(t, int32(postId), retrievedNotification.PostID.Int32)
}

func TestNoErrorWhenMarkingNonExistentNotification(t *testing.T) {
	ctx := context.Background()
	service, _ := setupNotificationService()
	user := createTestUser()

	err := service.MarkNotificationAsReadById(ctx, user, 999)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "notification does not belong to user")
}

func TestGetUserUnreadNotificationsCount(t *testing.T) {
	ctx := context.Background()
	service, fakeRepo := setupNotificationService()
	user := createTestUser()

	fakeRepo.AddNotification(createTestNotification(int(user.UserID), 1, "User 1 notification 1", true))
	fakeRepo.AddNotification(createTestNotification(int(user.UserID), 2, "User 1 notification 2", true))
	fakeRepo.AddNotification(createTestNotification(int(user.UserID), 3, "User 2 notification 1", false))

	count, err := service.GetUserUnreadNotificationCount(ctx, user)
	require.NoError(t, err)
	assert.Equal(t, 2, count)
}
