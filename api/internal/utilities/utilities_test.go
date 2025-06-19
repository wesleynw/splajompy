package utilities

import (
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

func TestMapNotification_WithInvalidPostIDAndCommentID(t *testing.T) {
	notification := queries.Notification{
		NotificationID: 123,
		UserID:         456,
		PostID:         pgtype.Int4{Int32: 999, Valid: false},
		CommentID:      pgtype.Int4{Int32: 888, Valid: false},
		Message:        "Test notification",
		Link:           pgtype.Text{String: "https://example.com", Valid: true},
		Viewed:         false,
		Facets:         db.Facets{},
		CreatedAt:      pgtype.Timestamp{Time: time.Now(), Valid: true},
	}

	result := MapNotification(notification)

	// When Valid=false, pointer fields should be nil
	// The actual Int32 values (999, 888) should be ignored when Valid=false
	assert.Nil(t, result.PostID, "PostID should be nil when pgtype.Int4.Valid is false")
	assert.Equal(t, 0, result.CommentID, "CommentID should be 0 when pgtype.Int4.Valid is false (since it's not a pointer)")

	// Other fields should map correctly
	assert.Equal(t, 123, result.NotificationID)
	assert.NotNil(t, result.UserID, "UserID should not be nil when it has a valid value")
	assert.Equal(t, 456, result.UserID, "UserID should be 456")
	assert.Equal(t, "Test notification", result.Message)
	assert.Equal(t, "https://example.com", result.Link)
	assert.Equal(t, false, result.Viewed)
}

func TestMapNotification_WithValidPostIDAndCommentID(t *testing.T) {
	// Test that when pgtype.Int4 fields have Valid=true, values are mapped correctly

	notification := queries.Notification{
		NotificationID: 123,
		UserID:         456,
		PostID:         pgtype.Int4{Int32: 789, Valid: true},
		CommentID:      pgtype.Int4{Int32: 101112, Valid: true},
		Message:        "Test notification",
		Link:           pgtype.Text{String: "https://example.com", Valid: true},
		Viewed:         true,
		Facets:         db.Facets{},
		CreatedAt:      pgtype.Timestamp{Time: time.Now(), Valid: true},
	}

	result := MapNotification(notification)

	assert.Equal(t, 789, result.PostID)
	assert.Equal(t, 101112, result.CommentID)
	assert.Equal(t, 123, result.NotificationID)
	assert.Equal(t, 456, result.UserID)
	assert.Equal(t, "Test notification", result.Message)
	assert.Equal(t, "https://example.com", result.Link)
	assert.Equal(t, true, result.Viewed)
}
