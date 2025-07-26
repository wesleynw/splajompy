package service

import (
	"context"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/repositories/fakes"
	"testing"
)

func TestFollowUser(t *testing.T) {
	ctx := context.Background()
	fakeUserRepo := fakes.NewFakeUserRepository()
	fakeNotificationRepo := fakes.NewFakeNotificationRepository()

	user1, err := fakeUserRepo.CreateUser(ctx, "user1", "user1@splajompy.com", "password123")
	require.NoError(t, err)
	user2, err := fakeUserRepo.CreateUser(ctx, "user2", "user2@splajompy.com", "password123")
	require.NoError(t, err)

	service := NewUserService(fakeUserRepo, fakeNotificationRepo, nil)

	err = service.FollowUser(ctx, user1, user2.UserID)
	require.NoError(t, err)

	following := fakeUserRepo.GetFollowingForUser(user1.UserID)
	assert.Equal(t, 1, len(following))
	assert.Contains(t, following, int32(user2.UserID))

	followers := fakeUserRepo.GetFollowersForUser(user2.UserID)
	assert.Equal(t, 1, len(followers))
	assert.Contains(t, followers, int32(user1.UserID))
}

func TestGetUserById_WithNoMutuals_ReturnsEmptyArray(t *testing.T) {
	ctx := context.Background()
	fakeUserRepo := fakes.NewFakeUserRepository()
	fakeNotificationRepo := fakes.NewFakeNotificationRepository()

	requestingUser, err := fakeUserRepo.CreateUser(ctx, "requester", "requester@splajompy.com", "password123")
	require.NoError(t, err)
	targetUser, err := fakeUserRepo.CreateUser(ctx, "target", "target@splajompy.com", "password123")
	require.NoError(t, err)

	service := NewUserService(fakeUserRepo, fakeNotificationRepo, nil)

	profile, err := service.GetUserById(ctx, requestingUser, targetUser.UserID)
	require.NoError(t, err)

	assert.NotNil(t, profile)
	assert.NotNil(t, profile.Mutuals)
	assert.Equal(t, []string{}, profile.Mutuals)
	assert.Equal(t, 0, len(profile.Mutuals))
}
