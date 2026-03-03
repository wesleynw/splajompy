package service_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/testutil"
)

type userServiceTestEnv struct {
	svc            *service.UserService
	userRepository repositories.UserRepository
}

func setupTest(t *testing.T) userServiceTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	notificationRepository := repositories.NewDBNotificationRepository(testDb.Queries)

	svc := service.NewUserService(userRepository, notificationRepository, nil)

	return userServiceTestEnv{
		svc:            svc,
		userRepository: userRepository,
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
