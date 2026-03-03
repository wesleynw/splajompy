package testutil

import (
	"testing"

	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
)

func CreateTestUser(t *testing.T, repo repositories.UserRepository, username string) models.PublicUser {
	t.Helper()
	user, err := repo.CreateUser(t.Context(), username, username+"@splajompy.com", "abc123", "abc123")
	require.NoError(t, err)
	return user
}
