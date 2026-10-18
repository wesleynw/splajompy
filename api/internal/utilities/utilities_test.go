package utilities_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/utilities"
)

func TestMapNotification_WithValidPostIDAndCommentID(t *testing.T) {
	postID := 789
	commentID := 101112
	notification := queries.Notification{
		NotificationID: 123,
		UserID:         456,
		PostID:         &postID,
		CommentID:      &commentID,
		Message:        "Test notification",
		Link:           new("https://example.com"),
		Viewed:         true,
		Facets:         db.Facets{},
		CreatedAt:      time.Now(),
	}

	result := utilities.MapNotification(notification)

	assert.Equal(t, 789, *result.PostID)
	assert.Equal(t, 101112, *result.CommentID)
	assert.Equal(t, 123, result.NotificationID)
	assert.Equal(t, 456, result.UserID)
	assert.Equal(t, "Test notification", result.Message)
	assert.Equal(t, "https://example.com", *result.Link)
	assert.Equal(t, true, result.Viewed)
}

func TestIsUpdatedToVersion_UnknownVersion(t *testing.T) {
	valid := utilities.IsAppUpdatedToVersion(t.Context(), "v1.0.0")
	assert.True(t, valid)
}

func TestIsUpdatedToVersion_PastVersion(t *testing.T) {
	ctx := context.WithValue(t.Context(), utilities.AppVersionKey, "v1.0.0")
	valid := utilities.IsAppUpdatedToVersion(ctx, "v1.1.0")
	assert.False(t, valid)
}

func TestIsUpdatedToVersion_FutureVersion(t *testing.T) {
	ctx := context.WithValue(t.Context(), utilities.AppVersionKey, "v1.1.0")
	valid := utilities.IsAppUpdatedToVersion(ctx, "v1.0.0")
	assert.True(t, valid)
}

func TestIsUpdatedToVersion_EqualVersion(t *testing.T) {
	ctx := context.WithValue(t.Context(), utilities.AppVersionKey, "v1.1.0")
	valid := utilities.IsAppUpdatedToVersion(ctx, "v1.1.0")
	assert.True(t, valid)
}

func TestSeededRandom(t *testing.T) {
	rand0 := utilities.SeededRandom(456)
	rand1 := utilities.SeededRandom(456)

	assert.Equal(t, rand0, rand1)
}
