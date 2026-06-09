package user_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/testutil"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"
)

type userServiceTestEnv struct {
	svc               *user.Service
	userRepository    user.Store
	notificationStore notification.Store
}

func setupTest(t *testing.T) userServiceTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)

	notificationService := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	svc := user.NewUserService(db.UserRepository, *notificationService, nil)

	return userServiceTestEnv{
		svc:               svc,
		userRepository:    db.UserRepository,
		notificationStore: db.NotificationStore,
	}
}

func TestSearchUsers_DoesNotReturnBlockedUser(t *testing.T) {
	env := setupTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	err := env.svc.BlockUser(t.Context(), user0, user1.UserID)
	require.NoError(t, err)

	users, err := env.svc.GetUserByUsernameSearch(t.Context(), "user0", user1.UserID)
	assert.NoError(t, err)
	for _, u := range *users {
		assert.NotEqual(t, user0.UserID, u.UserID)
	}
}

func TestGetNotificationActors_ReturnsLikingUsers(t *testing.T) {
	env := setupTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")
	user2 := testutil.CreateTestUser(t, env.userRepository, "user2")

	notification, err := env.notificationStore.InsertNotification(t.Context(), user0.UserID, nil, nil, nil, "test notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	page, err := env.svc.GetNotificationActors(t.Context(), user0.UserID, notification.NotificationID, 10, new(time.Now().UTC()))
	require.NoError(t, err)
	assert.Empty(t, page.Users)

	err = env.notificationStore.InsertNotificationActor(t.Context(), notification.NotificationID, user1.UserID)
	require.NoError(t, err)
	err = env.notificationStore.InsertNotificationActor(t.Context(), notification.NotificationID, user2.UserID)
	require.NoError(t, err)

	page, err = env.svc.GetNotificationActors(t.Context(), user0.UserID, notification.NotificationID, 10, new(time.Now().UTC()))
	require.NoError(t, err)
	require.NotNil(t, page)
	require.Len(t, page.Users, 2)
	userIDs := []int{page.Users[0].UserID, page.Users[1].UserID}
	assert.ElementsMatch(t, []int{user1.UserID, user2.UserID}, userIDs)
}

func TestGetNotificationActors_DoesntReturnForNonOwningUser(t *testing.T) {
	env := setupTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	notification, err := env.notificationStore.InsertNotification(t.Context(), user0.UserID, nil, nil, nil, "test notification", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	page, err := env.svc.GetNotificationActors(t.Context(), user1.UserID, notification.NotificationID, 10, new(time.Now().UTC()))
	assert.Nil(t, page)
	assert.ErrorIs(t, err, utilities.ErrUnauthorized)
}

func TestGetNotificationActors_ReturnsErrorWhenNotificationDoesNotExist(t *testing.T) {
	env := setupTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	page, err := env.svc.GetNotificationActors(t.Context(), user0.UserID, 500, 10, new(time.Now().UTC()))
	assert.ErrorIs(t, err, user.ErrNotificationDoesNotExist)
	assert.Nil(t, page)
}

func TestFollowUser_SendsNotification(t *testing.T) {
	env := setupTest(t)
	u0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	u1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	err := env.svc.FollowUser(t.Context(), u0, u1.UserID)
	require.NoError(t, err)

	notifications, err := env.notificationStore.GetUnreadNotificationsForUserIdWithTimeOffset(t.Context(), u1.UserID, time.Now().UTC(), 10, nil)
	require.NoError(t, err)

	assert.Len(t, notifications, 1)
	follow_notification := notifications[0]
	assert.Equal(t, "@user0 followed you", follow_notification.Message)
}

func TestFollowUser_Idempotent(t *testing.T) {
	env := setupTest(t)
	u0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	u1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	err := env.svc.FollowUser(t.Context(), u0, u1.UserID)
	require.NoError(t, err)

	err = env.svc.FollowUser(t.Context(), u0, u1.UserID)
	require.NoError(t, err)
}
