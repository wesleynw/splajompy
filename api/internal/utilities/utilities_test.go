package utilities

import (
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

func TestMapNotification_WithZeroPostIDAndCommentID(t *testing.T) {
	notification := queries.Notification{
		NotificationID: 123,
		UserID:         456,
		PostID:         nil,
		CommentID:      nil,
		Message:        "Test notification",
		Link:           pgtype.Text{String: "https://example.com", Valid: true},
		Viewed:         false,
		Facets:         db.Facets{},
		CreatedAt:      pgtype.Timestamp{Time: time.Now(), Valid: true},
	}

	result := MapNotification(notification)

	assert.Nil(t, result.PostID, "PostID should be nil when it's nil")
	assert.Nil(t, result.CommentID, "CommentID should be nil when it's nil")

	assert.Equal(t, 123, result.NotificationID)
	assert.NotNil(t, result.UserID, "UserID should not be nil when it has a valid value")
	assert.Equal(t, 456, result.UserID, "UserID should be 456")
	assert.Equal(t, "Test notification", result.Message)
	assert.Equal(t, "https://example.com", result.Link)
	assert.Equal(t, false, result.Viewed)
}

func TestMapNotification_WithValidPostIDAndCommentID(t *testing.T) {
	// Test that when int fields have non-zero values, they are mapped correctly

	postID := 789
	commentID := 101112
	notification := queries.Notification{
		NotificationID: 123,
		UserID:         456,
		PostID:         &postID,
		CommentID:      &commentID,
		Message:        "Test notification",
		Link:           pgtype.Text{String: "https://example.com", Valid: true},
		Viewed:         true,
		Facets:         db.Facets{},
		CreatedAt:      pgtype.Timestamp{Time: time.Now(), Valid: true},
	}

	result := MapNotification(notification)

	assert.Equal(t, 789, *result.PostID)
	assert.Equal(t, 101112, *result.CommentID)
	assert.Equal(t, 123, result.NotificationID)
	assert.Equal(t, 456, result.UserID)
	assert.Equal(t, "Test notification", result.Message)
	assert.Equal(t, "https://example.com", result.Link)
	assert.Equal(t, true, result.Viewed)
}
