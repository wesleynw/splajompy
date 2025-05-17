package service

import (
	"context"
	"errors"

	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/models"
)

type NotificationService struct {
	queries *db.Queries
}

func NewNotificationService(queries *db.Queries) *NotificationService {
	return &NotificationService{
		queries: queries,
	}
}

func (s *NotificationService) GetNotificationsByUserId(ctx context.Context, user models.PublicUser, offset int, limit int) (*[]db.Notification, error) {
	notifications, err := s.queries.GetNotificationsForUserId(ctx, db.GetNotificationsForUserIdParams{
		UserID: user.UserID,
		Offset: int32(offset),
		Limit:  int32(limit),
	})
	if err != nil {
		return nil, errors.New("unable to retrieve notifications")
	}

	if notifications == nil {
		return &[]db.Notification{}, nil
	}

	return &notifications, nil
}

func (s *NotificationService) MarkNotificationAsReadById(ctx context.Context, user models.PublicUser, notificationId int) error {
	notification, err := s.queries.GetNotificationById(ctx, int32(notificationId))
	if err != nil {
		return errors.New("unable to fetch notification")
	}

	if notification.UserID != int32(notificationId) {
		return errors.New("notification does not belong to user")
	}

	return s.queries.MarkNotificationAsReadById(ctx, int32(notificationId))
}

func (s *NotificationService) MarkAllNotificationsAsReadForUserId(ctx context.Context, user models.PublicUser) error {
	return s.queries.MarkAllNotificationsAsReadForUser(ctx, user.UserID)
}

func (s *NotificationService) UserHasUnreadNotifications(ctx context.Context, user models.PublicUser) (bool, error) {
	return s.queries.UserHasUnreadNotifications(ctx, user.UserID)
}
