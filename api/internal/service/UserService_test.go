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

	service := NewUserService(fakeUserRepo, fakeNotificationRepo)

	err = service.FollowUser(ctx, user1, int(user2.UserID))
	require.NoError(t, err)

	following := fakeUserRepo.GetFollowingForUser(int(user1.UserID))
	assert.Equal(t, 1, len(following))
	assert.Contains(t, following, user2.UserID)

	followers := fakeUserRepo.GetFollowersForUser(int(user2.UserID))
	assert.Equal(t, 1, len(followers))
	assert.Contains(t, followers, user1.UserID)
}
