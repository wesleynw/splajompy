package repositories

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type NotificationRepository interface {
	InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType models.NotificationType, targetUserId *int) error
	GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error)
	GetUnreadNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error)
	GetNotificationById(ctx context.Context, notificationId int) (*models.Notification, error)
	MarkNotificationAsRead(ctx context.Context, notificationId int) error
	MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error
	GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error)
	GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error)
	GetReadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error)
	GetUnreadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error)
	FindUnreadLikeNotification(ctx context.Context, userId int, postId int, commentId *int) (*models.Notification, error)
	DeleteNotificationById(ctx context.Context, notificationId int) error
}

type DBNotificationRepository struct {
	querier queries.Querier
}

// InsertNotification adds a new notification for a user
func (r DBNotificationRepository) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType models.NotificationType, targetUserId *int) error {
	params := queries.InsertNotificationParams{
		UserID:           userId,
		Message:          message,
		NotificationType: notificationType.String(),
	}

	if postId != nil {
		params.PostID = postId
	}
	if commentId != nil {
		params.CommentID = commentId
	}
	if facets != nil {
		params.Facets = *facets
	}
	if targetUserId != nil {
		params.TargetUserID = targetUserId
	}
	return r.querier.InsertNotification(ctx, params)
}

// GetNotificationsForUserId retrieves notifications for a user.
func (r DBNotificationRepository) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
	notifications, err := r.querier.GetNotificationsForUserId(ctx, queries.GetNotificationsForUserIdParams{
		UserID: userId,
		Offset: offset,
		Limit:  limit,
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
	notification, err := r.querier.GetNotificationById(ctx, notificationId)
	if err != nil {
		return nil, err
	}

	mapped := utilities.MapNotification(notification)
	return &mapped, nil
}

// MarkNotificationAsRead marks a notification as read
func (r DBNotificationRepository) MarkNotificationAsRead(ctx context.Context, notificationId int) error {
	return r.querier.MarkNotificationAsReadById(ctx, notificationId)
}

// MarkAllNotificationsAsReadForUser marks all notifications as read for a user
func (r DBNotificationRepository) MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error {
	return r.querier.MarkAllNotificationsAsReadForUser(ctx, userId)
}

// GetUserHasUnreadNotifications checks if a user has unread notifications
func (r DBNotificationRepository) GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error) {
	return r.querier.UserHasUnreadNotifications(ctx, userId)
}

func (r DBNotificationRepository) GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error) {
	count, err := r.querier.GetUserUnreadNotificationCount(ctx, userId)
	return int(count), err
}

// GetUnreadNotificationsForUserId retrieves unread notifications for a user with pagination
func (r DBNotificationRepository) GetUnreadNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
	notifications, err := r.querier.GetUnreadNotificationsForUserId(ctx, queries.GetUnreadNotificationsForUserIdParams{
		UserID: userId,
		Offset: offset,
		Limit:  limit,
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

// GetReadNotificationsForUserIdWithTimeOffset retrieves read notifications for a user with time-based pagination
func (r DBNotificationRepository) GetReadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error) {
	params := queries.GetReadNotificationsForUserIdWithTimeOffsetParams{
		UserID:    userId,
		CreatedAt: pgtype.Timestamp{Time: beforeTime, Valid: true},
		Limit:     limit,
	}

	if notificationType != nil {
		params.NotificationType = pgtype.Text{String: *notificationType, Valid: true}
	} else {
		params.NotificationType = pgtype.Text{Valid: false}
	}

	notifications, err := r.querier.GetReadNotificationsForUserIdWithTimeOffset(ctx, params)
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

// GetUnreadNotificationsForUserIdWithTimeOffset retrieves unread notifications for a user with time-based pagination
func (r DBNotificationRepository) GetUnreadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error) {
	params := queries.GetUnreadNotificationsForUserIdWithTimeOffsetParams{
		UserID:    userId,
		CreatedAt: pgtype.Timestamp{Time: beforeTime, Valid: true},
		Limit:     limit,
	}

	if notificationType != nil {
		params.NotificationType = pgtype.Text{String: *notificationType, Valid: true}
	} else {
		params.NotificationType = pgtype.Text{Valid: false}
	}

	notifications, err := r.querier.GetUnreadNotificationsForUserIdWithTimeOffset(ctx, params)
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

// FindUnreadLikeNotification finds an unread like notification for a user
func (r DBNotificationRepository) FindUnreadLikeNotification(ctx context.Context, userId int, postId int, commentId *int) (*models.Notification, error) {
	var notification queries.Notification
	var err error

	if commentId == nil {
		notification, err = r.querier.FindUnreadLikeNotificationForPost(ctx, queries.FindUnreadLikeNotificationForPostParams{
			UserID: userId,
			PostID: &postId,
		})
	} else {
		notification, err = r.querier.FindUnreadLikeNotificationForComment(ctx, queries.FindUnreadLikeNotificationForCommentParams{
			UserID:    userId,
			PostID:    &postId,
			CommentID: commentId,
		})
	}

	if err != nil {
		return nil, err
	}

	mapped := utilities.MapNotification(notification)
	return &mapped, nil
}

// DeleteNotificationById deletes a notification by its ID
func (r DBNotificationRepository) DeleteNotificationById(ctx context.Context, notificationId int) error {
	return r.querier.DeleteNotificationById(ctx, notificationId)
}

// NewDBNotificationRepository creates a new notification repository
func NewDBNotificationRepository(querier queries.Querier) NotificationRepository {
	return &DBNotificationRepository{querier: querier}
}
