package notification

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/repositories"

	"splajompy.com/api/v2/internal/models"
)

type Service struct {
	notificationRepository NotificationStore
	postRepository         repositories.PostRepository
	commentRepository      repositories.CommentRepository
	userRepository         repositories.UserRepository
	bucketRepository       bucket.Repository
}

func NewService(notificationRepository NotificationStore, postRepository repositories.PostRepository, commentRepository repositories.CommentRepository, userRepository repositories.UserRepository, bucketRepository bucket.Repository) *Service {
	return &Service{
		notificationRepository: notificationRepository,
		postRepository:         postRepository,
		commentRepository:      commentRepository,
		userRepository:         userRepository,
		bucketRepository:       bucketRepository,
	}
}

func (s *Service) MarkNotificationAsReadById(ctx context.Context, user models.PublicUser, notificationId int) error {
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

func (s *Service) MarkAllNotificationsAsReadForUserId(ctx context.Context, user models.PublicUser) error {
	return s.notificationRepository.MarkAllNotificationsAsReadForUser(ctx, user.UserID)
}

func (s *Service) UserHasUnreadNotifications(ctx context.Context, user models.PublicUser) (bool, error) {
	return s.notificationRepository.GetUserHasUnreadNotifications(ctx, user.UserID)
}

func (s *Service) GetUserUnreadNotificationCount(ctx context.Context, user models.PublicUser) (int, error) {
	return s.notificationRepository.GetUserUnreadNotificationCount(ctx, user.UserID)
}

func (s *Service) GetReadNotificationsByUserIdWithTimeOffset(ctx context.Context, user models.PublicUser, beforeTime time.Time, limit int, notificationType *string) ([]models.DetailedNotification, error) {
	notifications, err := s.notificationRepository.GetReadNotificationsForUserIdWithTimeOffset(ctx, user.UserID, beforeTime, limit, notificationType)
	if err != nil {
		return nil, errors.New("unable to retrieve read notifications")
	}

	if notifications == nil {
		return []models.DetailedNotification{}, nil
	}

	return s.buildDetailedNotifications(ctx, user.UserID, notifications)
}

func (s *Service) GetUnreadNotificationsByUserIdWithTimeOffset(ctx context.Context, user models.PublicUser, beforeTime time.Time, limit int, notificationType *string) ([]models.DetailedNotification, error) {
	notifications, err := s.notificationRepository.GetUnreadNotificationsForUserIdWithTimeOffset(ctx, user.UserID, beforeTime, limit, notificationType)
	if err != nil {
		return nil, errors.New("unable to retrieve unread notifications")
	}

	if notifications == nil {
		return []models.DetailedNotification{}, nil
	}

	return s.buildDetailedNotifications(ctx, user.UserID, notifications)
}

func (s *Service) buildDetailedNotifications(ctx context.Context, currentUserId int, notifications []*models.Notification) ([]models.DetailedNotification, error) {
	detailedNotifications := make([]models.DetailedNotification, 0, len(notifications))

	for _, notification := range notifications {
		var detailedNotification models.DetailedNotification
		detailedNotification.Notification = *notification

		if notification.PostID != nil {
			post, err := s.postRepository.GetPostById(ctx, *notification.PostID, currentUserId)
			if err != nil {
				return nil, errors.New("unable to retrieve post")
			}
			detailedNotification.Post = post

			images, err := s.postRepository.GetImagesForPost(ctx, *notification.PostID)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return nil, errors.New("unable to retrieve image blob")
			}

			if len(images) > 0 {
				url, err := s.bucketRepository.GetPresignedGetObject(ctx, images[0].ImageBlobUrl)
				if err != nil {
					return nil, errors.New("unable to retrieve image blob")
				}
				detailedNotification.ImageBlob = url
				detailedNotification.ImageWidth = &images[0].Width
				detailedNotification.ImageHeight = &images[0].Height
			}
		}

		if notification.CommentID != nil {
			comment, err := s.commentRepository.GetCommentById(ctx, *notification.CommentID)
			if err != nil {
				return nil, errors.New("unable to retrieve comment")
			}
			detailedNotification.Comment = &comment

			commentImages, err := s.commentRepository.GetImagesByCommentId(ctx, *notification.CommentID)
			if err != nil {
				return nil, errors.New("unable to retrieve comment images")
			}
			if len(commentImages) > 0 {
				presignedUrl, err := s.bucketRepository.GetPresignedGetObject(ctx, commentImages[0].ImageBlobUrl)
				if err != nil {
					return nil, errors.New("unable to presign comment image")
				}
				detailedNotification.ImageBlob = presignedUrl
				detailedNotification.ImageWidth = &commentImages[0].Width
				detailedNotification.ImageHeight = &commentImages[0].Height
			}
		}

		if notification.TargetUserId != nil {
			user, err := s.userRepository.GetUserById(ctx, *notification.TargetUserId)
			if err != nil {
				return nil, errors.New("unable to retrieve user")
			}
			detailedNotification.TargetUserUsername = &user.Username
		}

		detailedNotifications = append(detailedNotifications, detailedNotification)
	}

	return detailedNotifications, nil
}

// AddOrUpsertLikeNotification creates a like notification for the owner of the target post or comment
// or upserts an existing like notification, adding the current user.
// Pass nil for commentId when liking a post directly.
func (s *Service) AddOrUpsertLikeNotification(ctx context.Context, currentUserId int, postId int, commentId *int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUserId)
	if err != nil {
		return err
	}

	// do not self-notify
	if currentUserId == post.UserID {
		return nil
	}

	existingLikeNotification, err := s.notificationRepository.FindUnreadLikeNotification(ctx, post.UserID, postId, nil)
	if err != nil {
		return err
	}

	currentUser, err := s.userRepository.GetUserById(ctx, currentUserId)
	if err != nil {
		return err
	}

	// TODO: add a unique constraint on the notifications table (e.g. (user_id, post_id, notification_type) with a
	// partial index WHERE NOT viewed)
	if existingLikeNotification == nil {
		message, err := s.buildLikedMessage(ctx, []int{currentUser.UserID})
		if err != nil {
			return err
		}
		notification, err := s.AddNotification(ctx, post.UserID, postId, nil, *message, models.NotificationTypeLike)
		return s.notificationRepository.InsertNotificationActor(ctx, notification.NotificationID, currentUserId)
	}

	err = s.notificationRepository.InsertNotificationActor(ctx, existingLikeNotification.NotificationID, currentUserId)
	if err != nil {
		return err
	}

	actors, err := s.notificationRepository.GetNotificationActors(ctx, existingLikeNotification.NotificationID)
	if err != nil {
		return err
	}

	message, err := s.buildLikedMessage(ctx, actors)
	if err != nil {
		return err
	}

	return s.notificationRepository.UpdateNotificationMessage(ctx, existingLikeNotification.NotificationID, *message)
}

// AddNotification will enrich the notification message with facets, then store.
func (s *Service) AddNotification(ctx context.Context, targetUserId int, postId int, commentId *int, message string, notificationType models.NotificationType) (*models.Notification, error) {
	facets, err := repositories.GenerateFacets(ctx, s.userRepository, message)
	if err != nil {
		return nil, err
	}

	return s.notificationRepository.InsertNotification(ctx, targetUserId, &postId, commentId, &facets, message, notificationType, nil)
}

func (s *Service) DeleteNotificationById(ctx context.Context, notificationId int) error {
	return nil
}

func (s *Service) buildLikedMessage(ctx context.Context, userIds []int) (*string, error) {
	users := []models.PublicUser{}
	for _, userId := range userIds[:min(3, len(userIds))] {
		user, err := s.userRepository.GetUserById(ctx, userId)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	if len(users) == 1 {
		return new(fmt.Sprintf("@%s liked your post.", users[0].Username)), nil
	}

	if len(users) == 2 {
		return new(fmt.Sprintf("@%s and @%s liked your post.", users[0].Username, users[1].Username)), nil
	}

	// TODO
	return new(""), nil
}
