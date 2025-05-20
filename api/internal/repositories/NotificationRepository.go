package repositories

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type NotificationRepository interface {
	InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string) error
	GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]queries.Notification, error)
	GetNotificationById(ctx context.Context, notificationId int) (queries.Notification, error)
	MarkNotificationAsRead(ctx context.Context, notificationId int) error
	MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error
	GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error)
	GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error)
}

type DBNotificationRepository struct {
	querier queries.Querier
}

// InsertNotification adds a new notification for a user
func (r DBNotificationRepository) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string) error {
	params := queries.InsertNotificationParams{
		UserID:  int32(userId),
		Message: message,
	}

	if postId != nil {
		params.PostID = pgtype.Int4{Int32: int32(*postId), Valid: true}
	}
	if commentId != nil {
		params.CommentID = pgtype.Int4{Int32: int32(*commentId), Valid: true}
	}
	if facets != nil {
		params.Facets = *facets
	}
	return r.querier.InsertNotification(ctx, params)
}

// GetNotificationsForUserId retrieves notifications for a user with pagination
func (r DBNotificationRepository) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]queries.Notification, error) {
	return r.querier.GetNotificationsForUserId(ctx, queries.GetNotificationsForUserIdParams{
		UserID: int32(userId),
		Offset: int32(offset),
		Limit:  int32(limit),
	})
}

// GetNotificationById retrieves a notification by ID
func (r DBNotificationRepository) GetNotificationById(ctx context.Context, notificationId int) (queries.Notification, error) {
	return r.querier.GetNotificationById(ctx, int32(notificationId))
}

// MarkNotificationAsRead marks a notification as read
func (r DBNotificationRepository) MarkNotificationAsRead(ctx context.Context, notificationId int) error {
	return r.querier.MarkNotificationAsReadById(ctx, int32(notificationId))
}

// MarkAllNotificationsAsReadForUser marks all notifications as read for a user
func (r DBNotificationRepository) MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error {
	return r.querier.MarkAllNotificationsAsReadForUser(ctx, int32(userId))
}

// GetUserHasUnreadNotifications checks if a user has unread notifications
func (r DBNotificationRepository) GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error) {
	return r.querier.UserHasUnreadNotifications(ctx, int32(userId))
}

func (r DBNotificationRepository) GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error) {
	count, err := r.querier.GetUserUnreadNotificationCount(ctx, int32(userId))
	return int(count), err
}

// NewDBNotificationRepository creates a new notification repository
func NewDBNotificationRepository(querier queries.Querier) NotificationRepository {
	return &DBNotificationRepository{querier: querier}
}
