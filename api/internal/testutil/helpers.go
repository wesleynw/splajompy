package testutil

import (
	"testing"

	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/user"
)

func CreateTestUser(t *testing.T, repo user.Store, username string) models.PublicUser {
	t.Helper()
	u, err := repo.CreateUser(t.Context(), username, username+"@splajompy.com", "abc123", "abc123")
	require.NoError(t, err)
	return models.PublicUser{
		UserID:            u.UserID,
		Username:          u.Username,
		Name:              u.Name,
		CreatedAt:         u.CreatedAt,
		DisplayProperties: u.DisplayProperties,
	}
}
