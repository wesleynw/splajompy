package auth_test

import (
	"os"
	"testing"

	"github.com/resend/resend-go/v3"
	"github.com/stretchr/testify/assert"
	"splajompy.com/api/internal/auth"
	"splajompy.com/api/internal/testutil"
	"splajompy.com/api/internal/user"
)

type authServiceTestEnv struct {
	svc            *auth.Service
	userRepository user.Store
}

func setupAuthServiceTest(t *testing.T) authServiceTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)

	_ = os.Setenv("ENVIRONMENT", "test")

	svc := auth.NewService(db.UserRepository, db.PostRepository, db.BucketRepository, resend.NewClient("test-key"))

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
