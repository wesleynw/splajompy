package service

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/repositories/fakes"
)

func TestFollowUser(t *testing.T) {
	ctx := context.Background()
	fakeUserRepo := fakes.NewFakeUserRepository()
	fakeNotificationRepo := fakes.NewFakeNotificationRepository()

	user1, err := fakeUserRepo.CreateUser(ctx, "user1", "user1@splajompy.com", "password", "123")
	require.NoError(t, err)
	user2, err := fakeUserRepo.CreateUser(ctx, "user2", "user2@splajompy.com", "password", "123")
	require.NoError(t, err)

	service := NewUserService(fakeUserRepo, fakeNotificationRepo, nil)

	err = service.FollowUser(ctx, user1, user2.UserID)
	require.NoError(t, err)

	following := fakeUserRepo.GetFollowingForUser(user1.UserID)
	assert.Equal(t, 1, len(following))
	assert.Contains(t, following, user2.UserID)

	followers := fakeUserRepo.GetFollowersForUser(user2.UserID)
	assert.Equal(t, 1, len(followers))
	assert.Contains(t, followers, user1.UserID)
}

func TestGetUserById_WithNoMutuals_ReturnsEmptyArray(t *testing.T) {
	ctx := context.Background()
	fakeUserRepo := fakes.NewFakeUserRepository()
	fakeNotificationRepo := fakes.NewFakeNotificationRepository()

	requestingUser, err := fakeUserRepo.CreateUser(ctx, "requester", "requester@splajompy.com", "password", "123")
	require.NoError(t, err)
	targetUser, err := fakeUserRepo.CreateUser(ctx, "target", "target@splajompy.com", "password", "123")
	require.NoError(t, err)

	service := NewUserService(fakeUserRepo, fakeNotificationRepo, nil)

	profile, err := service.GetUserById(ctx, requestingUser, targetUser.UserID)
	require.NoError(t, err)

	assert.NotNil(t, profile)
	assert.NotNil(t, profile.Mutuals)
	assert.Equal(t, []string{}, profile.Mutuals)
	assert.Equal(t, 0, len(profile.Mutuals))
}

func TestUserRelationship_AddAndRetrieve(t *testing.T) {
	ctx := context.Background()

	fakeUserRepo := fakes.NewFakeUserRepository()

	service := NewUserService(fakeUserRepo, nil, nil)

	user0, err := fakeUserRepo.CreateUser(ctx, "user0", "email@email.com", "123", "123")
	require.NoError(t, err)

	user1, err := fakeUserRepo.CreateUser(ctx, "user1", "email-1@email.com", "123", "123")
	require.NoError(t, err)

	err = service.AddUserToCloseFriendsList(ctx, user0, user1.UserID)
	assert.NoError(t, err)

	users, err := service.GetCloseFriendsByUserId(ctx, user0, 10, nil)
	assert.NoError(t, err)
	assert.Contains(t, users, user1, "returned friends list does not contain target user")
}

func TestUserRelationship_AddRemoveAndRetrieve(t *testing.T) {
	ctx := context.Background()

	fakeUserRepo := fakes.NewFakeUserRepository()

	service := NewUserService(fakeUserRepo, nil, nil)

	user0, err := fakeUserRepo.CreateUser(ctx, "user0", "email@email.com", "123", "123")
	require.NoError(t, err)

	user1, err := fakeUserRepo.CreateUser(ctx, "user1", "email-1@email.com", "123", "123")
	require.NoError(t, err)

	err = service.AddUserToCloseFriendsList(ctx, user0, user1.UserID)
	assert.NoError(t, err)

	err = service.RemoveUserFromCloseFriendsList(ctx, user0, user1.UserID)
	assert.NoError(t, err)

	users, err := service.GetCloseFriendsByUserId(ctx, user0, 10, nil)
	assert.NoError(t, err)
	assert.NotContains(t, users, user1, "returned friends list contains target user when it should have been removed")
}

func TestUserRelationship_AddAndGetPaged(t *testing.T) {
	ctx := context.Background()

	fakeUserRepo := fakes.NewFakeUserRepository()

	service := NewUserService(fakeUserRepo, nil, nil)

	user0, err := fakeUserRepo.CreateUser(ctx, "user0", "email@email.com", "123", "123")
	require.NoError(t, err)

	user1, err := fakeUserRepo.CreateUser(ctx, "user1", "email-1@email.com", "123", "123")
	require.NoError(t, err)

	err = service.AddUserToCloseFriendsList(ctx, user0, user1.UserID)
	assert.NoError(t, err)

	before := time.Now().AddDate(1, 0, 0)
	users, err := service.GetCloseFriendsByUserId(ctx, user0, 10, &before)
	assert.NoError(t, err)
	assert.NotContains(t, users, user1, "returned friends list contains target user when it should have been removed")
}
