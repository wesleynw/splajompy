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
	db := testutil.StartPostgres(t)

	_ = os.Setenv("ENVIRONMENT", "test")

	svc := service.NewAuthService(db.UserRepository, db.PostRepository, db.BucketRepository, nil)

	return authServiceTestEnv{
		svc:            svc,
		userRepository: db.UserRepository,
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
