package notification

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type NotificationStore struct {
	querier queries.Querier
}

// InsertNotification adds a new notification for a user
func (r NotificationStore) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType models.NotificationType, targetUserId *int) (*models.Notification, error) {
	params := queries.InsertNotificationParams{
		UserID:           userId,
		Message:          message,
		NotificationType: string(notificationType),
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
	notification, err := r.querier.InsertNotification(ctx, params)
	if err != nil {
		return nil, err
	}

	return new(utilities.MapNotification(notification)), nil
}

// GetNotificationsForUserId retrieves notifications for a user.
func (r NotificationStore) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
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
func (r NotificationStore) GetNotificationById(ctx context.Context, notificationId int) (*models.Notification, error) {
	notification, err := r.querier.GetNotificationById(ctx, notificationId)
	if err != nil {
		return nil, err
	}

	return new(utilities.MapNotification(notification)), nil
}

// MarkNotificationAsRead marks a notification as read
func (r NotificationStore) MarkNotificationAsRead(ctx context.Context, notificationId int) error {
	return r.querier.MarkNotificationAsReadById(ctx, notificationId)
}

// MarkAllNotificationsAsReadForUser marks all notifications as read for a user
func (r NotificationStore) MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error {
	return r.querier.MarkAllNotificationsAsReadForUser(ctx, userId)
}

// GetUserHasUnreadNotifications checks if a user has unread notifications
func (r NotificationStore) GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error) {
	return r.querier.UserHasUnreadNotifications(ctx, userId)
}

func (r NotificationStore) GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error) {
	count, err := r.querier.GetUserUnreadNotificationCount(ctx, userId)
	return int(count), err
}

// GetReadNotificationsForUserIdWithTimeOffset retrieves read notifications for a user with time-based pagination
func (r NotificationStore) GetReadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error) {
	params := queries.GetNotificationsForUserIdWithTimeOffsetParams{
		UserID:    userId,
		CreatedAt: pgtype.Timestamp{Time: beforeTime, Valid: true},
		Limit:     limit,
		Viewed:    true,
	}

	if notificationType != nil {
		params.NotificationType = pgtype.Text{String: *notificationType, Valid: true}
	} else {
		params.NotificationType = pgtype.Text{Valid: false}
	}

	notifications, err := r.querier.GetNotificationsForUserIdWithTimeOffset(ctx, params)
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
func (r NotificationStore) GetUnreadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error) {
	params := queries.GetNotificationsForUserIdWithTimeOffsetParams{
		UserID:    userId,
		CreatedAt: pgtype.Timestamp{Time: beforeTime, Valid: true},
		Limit:     limit,
		Viewed:    false,
	}

	if notificationType != nil {
		params.NotificationType = pgtype.Text{String: *notificationType, Valid: true}
	} else {
		params.NotificationType = pgtype.Text{Valid: false}
	}

	notifications, err := r.querier.GetNotificationsForUserIdWithTimeOffset(ctx, params)
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

// FindLikeNotification finds the most recent like notification for a user on a post or comment
func (r NotificationStore) FindLikeNotification(ctx context.Context, userId int, postId int, commentId *int) (*models.Notification, error) {
	var notification queries.Notification
	var err error

	if commentId == nil {
		notification, err = r.querier.FindLikeNotificationForPost(ctx, queries.FindLikeNotificationForPostParams{
			UserID: userId,
			PostID: &postId,
		})
	} else {
		notification, err = r.querier.FindLikeNotificationForComment(ctx, queries.FindLikeNotificationForCommentParams{
			UserID:    userId,
			PostID:    &postId,
			CommentID: commentId,
		})
	}

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	return new(utilities.MapNotification(notification)), nil
}

// DeleteNotificationById deletes a notification by its ID
func (r NotificationStore) DeleteNotificationById(ctx context.Context, notificationId int) error {
	return r.querier.DeleteNotificationById(ctx, notificationId)
}

func (r *NotificationStore) InsertNotificationActor(ctx context.Context, notificationId int, userId int) error {
	return r.querier.InsertNotificationActor(ctx, queries.InsertNotificationActorParams{
		NotificationID: notificationId,
		UserID:         userId,
	})
}

func (r *NotificationStore) DeleteNotificationActor(ctx context.Context, notificationId int, userId int) error {
	return r.querier.DeleteNotificationActor(ctx, queries.DeleteNotificationActorParams{
		NotificationID: notificationId,
		UserID:         userId,
	})
}

func (r *NotificationStore) GetNotificationActors(ctx context.Context, notificationId int) ([]int, error) {
	return r.querier.GetNotificationActors(ctx, notificationId)
}
func (r *NotificationStore) UpdateNotificationMessage(ctx context.Context, notificationId int, message string, facets db.Facets) error {
	return r.querier.UpdateNotificationMessage(ctx, queries.UpdateNotificationMessageParams{
		NotificationID: notificationId,
		Message:        message,
		Facets:         facets,
	})
}

func (r *NotificationStore) UpdateNotificationMessageOnly(ctx context.Context, notificationId int, message string, facets db.Facets) error {
	return r.querier.UpdateNotificationMessageOnly(ctx, queries.UpdateNotificationMessageOnlyParams{
		NotificationID: notificationId,
		Message:        message,
		Facets:         facets,
	})
}

func (r *NotificationStore) InsertDeviceToken(ctx context.Context, userId int, deviceId string, deviceToken string) error {
	return r.querier.InsertDeviceToken(ctx, queries.InsertDeviceTokenParams{
		UserID:      userId,
		DeviceID:    deviceId,
		DeviceToken: deviceToken,
	})
}

func (r *NotificationStore) GetDeviceTokensForUser(ctx context.Context, userId int) ([]string, error) {
	return r.querier.GetDeviceTokensForUser(ctx, userId)
}

// NewNotificationStore creates a new notification repository
func NewNotificationStore(querier queries.Querier) NotificationStore {
	return NotificationStore{querier: querier}
}
