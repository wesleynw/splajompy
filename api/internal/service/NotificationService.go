package service

import (
	"context"
	"errors"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/repositories"

	"splajompy.com/api/v2/internal/models"
)

type NotificationService struct {
	notificationRepository repositories.NotificationRepository
}

func NewNotificationService(notificationRepository repositories.NotificationRepository) *NotificationService {
	return &NotificationService{
		notificationRepository: notificationRepository,
	}
}

func (s *NotificationService) GetNotificationsByUserId(ctx context.Context, user models.PublicUser, offset int, limit int) (*[]queries.Notification, error) {
	notifications, err := s.notificationRepository.GetNotificationsForUserId(ctx, int(user.UserID), offset, limit)
	if err != nil {
		return nil, errors.New("unable to retrieve notifications")
	}

	if notifications == nil {
		return &[]queries.Notification{}, nil
	}

	return &notifications, nil
}

func (s *NotificationService) MarkNotificationAsReadById(ctx context.Context, user models.PublicUser, notificationId int) error {
	notification, err := s.notificationRepository.GetNotificationById(ctx, notificationId)
	if err != nil {
		return errors.New("unable to fetch notification")
	}

	if notification.UserID != int32(notificationId) {
		return errors.New("notification does not belong to user")
	}

	return s.notificationRepository.MarkNotificationAsRead(ctx, notificationId)
}

func (s *NotificationService) MarkAllNotificationsAsReadForUserId(ctx context.Context, user models.PublicUser) error {
	return s.notificationRepository.MarkAllNotificationsAsReadForUser(ctx, int(user.UserID))
}

func (s *NotificationService) UserHasUnreadNotifications(ctx context.Context, user models.PublicUser) (bool, error) {
	return s.notificationRepository.GetUserHasUnreadNotifications(ctx, int(user.UserID))
}
