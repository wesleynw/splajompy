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

type Store struct {
	querier queries.Querier
}

// InsertNotification adds a new notification for a user
func (r Store) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType models.NotificationType, targetUserId *int) (*models.Notification, error) {
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
func (r Store) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
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
		result[i] = new(utilities.MapNotification(notification))
	}

	return result, nil
}

// GetNotificationById retrieves a notification by ID
func (r Store) GetNotificationById(ctx context.Context, notificationId int) (*models.Notification, error) {
	notification, err := r.querier.GetNotificationById(ctx, notificationId)
	if err != nil {
		return nil, err
	}

	return new(utilities.MapNotification(notification)), nil
}

// MarkNotificationAsRead marks a notification as read
func (r Store) MarkNotificationAsRead(ctx context.Context, notificationId int) error {
	return r.querier.MarkNotificationAsReadById(ctx, notificationId)
}

// MarkAllNotificationsAsReadForUser marks all notifications as read for a user
func (r Store) MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error {
	return r.querier.MarkAllNotificationsAsReadForUser(ctx, userId)
}

// GetUserHasUnreadNotifications checks if a user has unread notifications
func (r Store) GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error) {
	return r.querier.UserHasUnreadNotifications(ctx, userId)
}

func (r Store) GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error) {
	count, err := r.querier.GetUserUnreadNotificationCount(ctx, userId)
	return int(count), err
}

// GetReadNotificationsForUserIdWithTimeOffset retrieves read notifications for a user with time-based pagination
func (r Store) GetReadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error) {
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
		result[i] = new(utilities.MapNotification(notification))
	}

	return result, nil
}

// GetUnreadNotificationsForUserIdWithTimeOffset retrieves unread notifications for a user with time-based pagination
func (r Store) GetUnreadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int, notificationType *string) ([]*models.Notification, error) {
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
		result[i] = new(utilities.MapNotification(notification))
	}

	return result, nil
}

// FindLikeNotification finds the most recent like notification for a user on a post or comment
func (r Store) FindLikeNotification(ctx context.Context, userId int, postId int, commentId *int) (*models.Notification, error) {
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
func (r Store) DeleteNotificationById(ctx context.Context, notificationId int) error {
	return r.querier.DeleteNotificationById(ctx, notificationId)
}

func (r Store) InsertNotificationActor(ctx context.Context, notificationId int, userId int) error {
	return r.querier.InsertNotificationActor(ctx, queries.InsertNotificationActorParams{
		NotificationID: notificationId,
		UserID:         userId,
	})
}

func (r Store) DeleteNotificationActor(ctx context.Context, notificationId int, userId int) error {
	return r.querier.DeleteNotificationActor(ctx, queries.DeleteNotificationActorParams{
		NotificationID: notificationId,
		UserID:         userId,
	})
}

func (r Store) GetNotificationActors(ctx context.Context, notificationId int) ([]int, error) {
	return r.querier.GetNotificationActors(ctx, notificationId)
}
func (r Store) UpdateNotificationMessage(ctx context.Context, notificationId int, message string, facets db.Facets) error {
	return r.querier.UpdateNotificationMessage(ctx, queries.UpdateNotificationMessageParams{
		NotificationID: notificationId,
		Message:        message,
		Facets:         facets,
	})
}

func (r Store) UpdateNotificationMessageOnly(ctx context.Context, notificationId int, message string, facets db.Facets) error {
	return r.querier.UpdateNotificationMessageOnly(ctx, queries.UpdateNotificationMessageOnlyParams{
		NotificationID: notificationId,
		Message:        message,
		Facets:         facets,
	})
}

func (r Store) InsertDeviceToken(ctx context.Context, userId int, deviceToken string, mentionsEnabled bool, commentsEnabled bool, followsEnabled bool) error {
	return r.querier.InsertDeviceToken(ctx, queries.InsertDeviceTokenParams{
		UserID:            userId,
		Token:             deviceToken,
		IsEnabledMentions: mentionsEnabled,
		IsEnabledComments: commentsEnabled,
		IsEnabledFollows:  followsEnabled,
	})
}

func (r Store) GetDeviceTokensForUser(ctx context.Context, userId int) ([]models.Device, error) {
	tokens, err := r.querier.GetDeviceTokensForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	result := make([]models.Device, len(tokens))
	for i, token := range tokens {
		result[i] = utilities.MapToken(token)
	}

	return result, nil
}

// NewNotificationStore creates a new notification repository
func NewNotificationStore(querier queries.Querier) Store {
	return Store{querier: querier}
}
