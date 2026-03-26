package service_test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/testutil"
)

type authServiceTestEnv struct {
	svc            *service.AuthService
	userRepository repositories.UserRepository
}

func setupAuthServiceTest(t *testing.T) authServiceTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	bucketRepository := &fakeBucketRepository{}

	svc := service.NewAuthService(userRepository, postRepository, bucketRepository, nil)

	_ = os.Setenv("ENVIRONMENT", "test")

	return authServiceTestEnv{
		svc:            svc,
		userRepository: userRepository,
	}
}

func TestDeleteAccount(t *testing.T) {
	env := setupAuthServiceTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	err := env.svc.DeleteAccount(t.Context(), user0)
	assert.NoError(t, err)

	_, err = env.userRepository.GetUserById(t.Context(), user0.UserID)
	assert.Error(t, err)
}
