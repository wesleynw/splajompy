package repositories

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type NotificationRepository interface {
	InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType string) error
	GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error)
	GetUnreadNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error)
	GetNotificationById(ctx context.Context, notificationId int) (*models.Notification, error)
	MarkNotificationAsRead(ctx context.Context, notificationId int) error
	MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error
	GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error)
	GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error)
}

type DBNotificationRepository struct {
	querier queries.Querier
}

// InsertNotification adds a new notification for a user
func (r DBNotificationRepository) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType string) error {
	params := queries.InsertNotificationParams{
		UserID:           int32(userId),
		Message:          message,
		NotificationType: notificationType,
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
func (r DBNotificationRepository) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
	notifications, err := r.querier.GetNotificationsForUserId(ctx, queries.GetNotificationsForUserIdParams{
		UserID: int32(userId),
		Offset: int32(offset),
		Limit:  int32(limit),
	})
	if err != nil {
		return nil, err
	}

	result := make([]*models.Notification, len(notifications))
	for i, notification := range notifications {
		mapped := utilities.MapNotification(notification)
		result[i] = &mapped
	}

	return result, nil
}

// GetNotificationById retrieves a notification by ID
func (r DBNotificationRepository) GetNotificationById(ctx context.Context, notificationId int) (*models.Notification, error) {
	notification, err := r.querier.GetNotificationById(ctx, int32(notificationId))
	if err != nil {
		return nil, err
	}

	mapped := utilities.MapNotification(notification)
	return &mapped, nil
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

// GetUnreadNotificationsForUserId retrieves unread notifications for a user with pagination
func (r DBNotificationRepository) GetUnreadNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
	notifications, err := r.querier.GetUnreadNotificationsForUserId(ctx, queries.GetUnreadNotificationsForUserIdParams{
		UserID: int32(userId),
		Offset: int32(offset),
		Limit:  int32(limit),
	})
	if err != nil {
		return nil, err
	}

	result := make([]*models.Notification, len(notifications))
	for i, notification := range notifications {
		mapped := utilities.MapNotification(notification)
		result[i] = &mapped
	}

	return result, nil
}

// NewDBNotificationRepository creates a new notification repository
func NewDBNotificationRepository(querier queries.Querier) NotificationRepository {
	return &DBNotificationRepository{querier: querier}
}
