package service

import (
	"context"
	"database/sql"
	"errors"
	"splajompy.com/api/v2/internal/repositories"

	"splajompy.com/api/v2/internal/models"
)

type NotificationService struct {
	notificationRepository repositories.NotificationRepository
	postRepository         repositories.PostRepository
	commentRepository      repositories.CommentRepository
}

func NewNotificationService(notificationRepository repositories.NotificationRepository, postRepository repositories.PostRepository, commentRepository repositories.CommentRepository) *NotificationService {
	return &NotificationService{
		notificationRepository: notificationRepository,
		postRepository:         postRepository,
		commentRepository:      commentRepository,
	}
}

func (s *NotificationService) GetNotificationsByUserId(ctx context.Context, user models.PublicUser, offset int, limit int) ([]models.DetailedNotification, error) {
	notifications, err := s.notificationRepository.GetNotificationsForUserId(ctx, user.UserID, offset, limit)
	if err != nil {
		return nil, errors.New("unable to retrieve notifications")
	}

	if notifications == nil {
		return []models.DetailedNotification{}, nil
	}

	detailedNotifications := make([]models.DetailedNotification, 0, len(notifications))

	for _, notification := range notifications {
		var detailedNotification models.DetailedNotification
		detailedNotification.Notification = *notification

		if notification.PostID != nil {
			post, err := s.postRepository.GetPostById(ctx, *notification.PostID)
			if err != nil {
				return nil, errors.New("unable to retrieve post")
			}
			detailedNotification.Post = post

			imageBlob, err := s.postRepository.GetImagesForPost(ctx, *notification.PostID)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return nil, errors.New("unable to retrieve image blob")
			}

			if len(imageBlob) > 0 {
				url := "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/" + imageBlob[0].ImageBlobUrl
				detailedNotification.ImageBlob = &url
			}
		}

		if notification.CommentID != nil {
			comment, err := s.commentRepository.GetCommentById(ctx, *notification.CommentID)
			if err != nil {
				return nil, errors.New("unable to retrieve comment")
			}
			detailedNotification.Comment = &comment
		}

		detailedNotifications = append(detailedNotifications, detailedNotification)
	}

	return detailedNotifications, nil
}

func (s *NotificationService) MarkNotificationAsReadById(ctx context.Context, user models.PublicUser, notificationId int) error {
	notification, err := s.notificationRepository.GetNotificationById(ctx, notificationId)
	if err != nil {
		return errors.New("unable to fetch notification")
	}

	if notification == nil {
		return errors.New("notification does not belong to user")
	}

	if notification.UserID != user.UserID {
		return errors.New("notification does not belong to user")
	}

	return s.notificationRepository.MarkNotificationAsRead(ctx, notificationId)
}

func (s *NotificationService) MarkAllNotificationsAsReadForUserId(ctx context.Context, user models.PublicUser) error {
	return s.notificationRepository.MarkAllNotificationsAsReadForUser(ctx, user.UserID)
}

func (s *NotificationService) UserHasUnreadNotifications(ctx context.Context, user models.PublicUser) (bool, error) {
	return s.notificationRepository.GetUserHasUnreadNotifications(ctx, user.UserID)
}

func (s *NotificationService) GetUserUnreadNotificationCount(ctx context.Context, user models.PublicUser) (int, error) {
	return s.notificationRepository.GetUserUnreadNotificationCount(ctx, user.UserID)
}
