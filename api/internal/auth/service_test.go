package auth_test

import (
	"os"
	"testing"
	"testing/synctest"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/auth"
	"splajompy.com/api/v2/internal/email"
	"splajompy.com/api/v2/internal/testutil"
	"splajompy.com/api/v2/internal/user"
)

type authServiceTestEnv struct {
	svc             *auth.Service
	userRepository  user.Store
	mockEmailClient *email.MockEmailClient
	handler         *auth.Handler
}

func setupAuthServiceTest(t *testing.T) authServiceTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)

	_ = os.Setenv("ENVIRONMENT", "test")

	mockEmailClient := email.NewMockEmailClient()

	svc := auth.NewService(db.UserRepository, db.PostRepository, db.BucketRepository, mockEmailClient)

	return authServiceTestEnv{
		svc:             svc,
		userRepository:  db.UserRepository,
		mockEmailClient: mockEmailClient,
		handler:         auth.NewHandler(svc),
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

func TestVerifyEmail_NoCodeRequested(t *testing.T) {
	env := setupAuthServiceTest(t)

	err := env.svc.VerifyEmail(t.Context(), "test@splajompy.com", "123")
	assert.ErrorIs(t, err, auth.ErrEmailVerificationFailed)
}

func TestVerifyEmail_IncorrectCode(t *testing.T) {
	env := setupAuthServiceTest(t)

	err := env.svc.RequestEmailVerification(t.Context(), "test@splajompy.com")
	require.NoError(t, err)

	err = env.svc.VerifyEmail(t.Context(), "test@splajompy.com", "0000000") // 7 digit code impossible
	assert.ErrorIs(t, err, auth.ErrEmailVerificationFailed)
}

func TestVerifyEmail_NoCrossEmailMatch(t *testing.T) {
	env := setupAuthServiceTest(t)

	err := env.svc.RequestEmailVerification(t.Context(), "test0@splajompy.com")
	require.NoError(t, err)
	code := env.mockEmailClient.Requests[0].Subject[0:5]

	err = env.svc.RequestEmailVerification(t.Context(), "test1@splajompy.com")
	require.NoError(t, err)

	err = env.svc.VerifyEmail(t.Context(), "test1@splajompy.com", code)
	assert.ErrorIs(t, err, auth.ErrEmailVerificationFailed)
}

func TestVerifyEmail_NoExpiredCode(t *testing.T) {
	env := setupAuthServiceTest(t)
	synctest.Test(t, func(t *testing.T) {
		err := env.svc.RequestEmailVerification(t.Context(), "test0@splajompy.com")
		require.NoError(t, err)
		code := env.mockEmailClient.Requests[0].Subject[0:5]

		synctest.Sleep(time.Hour)

		err = env.svc.VerifyEmail(t.Context(), "test1@splajompy.com", code)
		assert.ErrorIs(t, err, auth.ErrEmailVerificationFailed)
	})
}

func TestVerifyEmail_OldCodeFails(t *testing.T) {
	env := setupAuthServiceTest(t)

	err := env.svc.RequestEmailVerification(t.Context(), "test0@splajompy.com")
	require.NoError(t, err)
	code := env.mockEmailClient.Requests[0].Subject[0:6]

	err = env.svc.RequestEmailVerification(t.Context(), "test0@splajompy.com")
	require.NoError(t, err)

	err = env.svc.VerifyEmail(t.Context(), "test0@splajompy.com", code)
	assert.ErrorIs(t, err, auth.ErrEmailVerificationFailed)
}

func TestVerifyEmail_Succeeds(t *testing.T) {
	env := setupAuthServiceTest(t)

	err := env.svc.RequestEmailVerification(t.Context(), "test0@splajompy.com")
	require.NoError(t, err)
	code := env.mockEmailClient.Requests[0].Subject[0:6]

	err = env.svc.VerifyEmail(t.Context(), "test0@splajompy.com", code)
	assert.NoError(t, err)
}
