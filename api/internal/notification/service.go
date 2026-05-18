package notification

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/utilities"

	"splajompy.com/api/v2/internal/models"
)

type Service struct {
	notificationRepository NotificationStore
	postRepository         postReader
	commentRepository      commentReader
	userRepository         userReader
	bucketRepository       bucket.Repository
	apnsClient             apns.Client
}

type postReader interface {
	GetPostById(ctx context.Context, postId int, currentUserId int) (*models.Post, error)
	GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error)
}

type userReader interface {
	GetUserById(ctx context.Context, userId int) (models.PublicUser, error)
	GetUserByUsername(ctx context.Context, username string) (models.PublicUser, error)
	GetUserLatestAppVersion(ctx context.Context, userId int) (*string, error)
	GetUserDisplayProperties(ctx context.Context, userId int) (*db.UserDisplayProperties, error)
}

type commentReader interface {
	GetCommentById(ctx context.Context, commentId int) (queries.Comment, error)
	GetImagesByCommentId(ctx context.Context, commentId int) ([]queries.Image, error)
}

func NewService(notificationRepository NotificationStore, postRepository postReader, commentRepository commentReader, userRepository userReader, bucketRepository bucket.Repository, apnClient apns.Client) *Service {
	return &Service{
		notificationRepository: notificationRepository,
		postRepository:         postRepository,
		commentRepository:      commentRepository,
		userRepository:         userRepository,
		bucketRepository:       bucketRepository,
		apnsClient:             apnClient,
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
				return nil, errors.New("unable to retrieve post referenced in notification")
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

		if notification.NotificationType == models.NotificationTypeLike {
			actors, err := s.notificationRepository.GetNotificationActors(ctx, notification.NotificationID)
			if err != nil {
				return nil, errors.New("unable to retrieve notification actors")
			}
			detailedNotification.HasNotificationActors = len(actors) > 0
		}

		detailedNotifications = append(detailedNotifications, detailedNotification)
	}

	return detailedNotifications, nil
}

// AddLikeNotification creates a like notification for the owner of the target post or comment
// or upserts an existing like notification, adding the current user.
// Pass nil for commentId when liking a post directly.
func (s *Service) AddLikeNotification(ctx context.Context, currentUserId int, postId int, commentId *int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUserId)
	if err != nil {
		return err
	}

	// resolve recipient: comment author for comment likes, post author otherwise
	recipientId := post.UserID
	if commentId != nil {
		comment, err := s.commentRepository.GetCommentById(ctx, *commentId)
		if err != nil {
			return err
		}
		recipientId = comment.UserID
	}

	// do not self-notify
	if currentUserId == recipientId {
		return nil
	}

	currentUser, err := s.userRepository.GetUserById(ctx, currentUserId)
	if err != nil {
		return err
	}

	recipientVersion, err := s.userRepository.GetUserLatestAppVersion(ctx, recipientId)
	if err != nil {
		return err
	}

	if !utilities.IsStoredVersionAtLeast(recipientVersion, "v1.8.2") {
		// Recipient is on an old client that can't navigate to the actors list —
		// send a plain per-liker notification instead of combining.
		message, err := s.buildLikedMessage(ctx, []int{currentUserId}, commentId != nil)
		if err != nil {
			return err
		}
		_, err = s.AddNotification(ctx, recipientId, postId, commentId, *message, models.NotificationTypeLike)
		return err
	}

	existingLikeNotification, err := s.notificationRepository.FindLikeNotification(ctx, recipientId, postId, commentId)
	if err != nil {
		return err
	}

	// TODO: add a unique constraint on the notifications table (e.g. (user_id, post_id, notification_type))
	if existingLikeNotification == nil {
		message, err := s.buildLikedMessage(ctx, []int{currentUser.UserID}, commentId != nil)
		if err != nil {
			return err
		}
		notification, err := s.AddNotification(ctx, recipientId, postId, commentId, *message, models.NotificationTypeLike)
		if err != nil {
			return err
		}
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

	message, err := s.buildLikedMessage(ctx, actors, commentId != nil)
	if err != nil {
		return err
	}

	facets, err := utilities.GenerateFacets(ctx, s.userRepository, *message)
	if err != nil {
		return err
	}

	return s.notificationRepository.UpdateNotificationMessage(ctx, existingLikeNotification.NotificationID, *message, facets)
}

// RemoveLikeNotification updates relevant notifications that reference the current user liking a post, and removes
// the notification entirely if the current user is the only liker.
func (s *Service) RemoveLikeNotification(ctx context.Context, currentUserId int, postId int, commentId *int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUserId)
	if err != nil {
		return err
	}

	// resolve recipient: comment author for comment likes, post author otherwise
	recipientId := post.UserID
	if commentId != nil {
		comment, err := s.commentRepository.GetCommentById(ctx, *commentId)
		if err != nil {
			return err
		}
		recipientId = comment.UserID
	}

	existingLikeNotification, err := s.notificationRepository.FindLikeNotification(ctx, recipientId, postId, commentId)
	if err != nil || existingLikeNotification == nil {
		return err
	}

	recipientVersion, err := s.userRepository.GetUserLatestAppVersion(ctx, recipientId)
	if err != nil {
		return err
	}

	if !utilities.IsStoredVersionAtLeast(recipientVersion, "v1.8.2") {
		// Old client: plain notifications were created without actor tracking, just delete directly.
		return s.notificationRepository.DeleteNotificationById(ctx, existingLikeNotification.NotificationID)
	}

	err = s.notificationRepository.DeleteNotificationActor(ctx, existingLikeNotification.NotificationID, currentUserId)
	if err != nil {
		return err
	}

	actors, err := s.notificationRepository.GetNotificationActors(ctx, existingLikeNotification.NotificationID)
	if err != nil {
		return err
	}

	if len(actors) == 0 {
		return s.notificationRepository.DeleteNotificationById(ctx, existingLikeNotification.NotificationID)
	}

	message, err := s.buildLikedMessage(ctx, actors, commentId != nil)
	if err != nil {
		return err
	}

	facets, err := utilities.GenerateFacets(ctx, s.userRepository, *message)
	if err != nil {
		return err
	}

	return s.notificationRepository.UpdateNotificationMessageOnly(ctx, existingLikeNotification.NotificationID, *message, facets)
}

// AddNotification will enrich the notification message with facets, then store.
func (s *Service) AddNotification(ctx context.Context, targetUserId int, postId int, commentId *int, message string, notificationType models.NotificationType) (*models.Notification, error) {
	facets, err := utilities.GenerateFacets(ctx, s.userRepository, message)
	if err != nil {
		return nil, err
	}

	notification, err := s.notificationRepository.InsertNotification(ctx, targetUserId, &postId, commentId, &facets, message, notificationType, nil)
	if err != nil {
		return nil, err
	}

	var identifier int
	switch notificationType {
	case models.NotificationTypeComment:
		identifier = postId
	case models.NotificationTypeFollowers:
		identifier = targetUserId
	default:
		identifier = 0
	}

	s.sendPushIfEnabled(ctx, targetUserId, message, notificationType, identifier)

	return notification, nil
}

// sendPushIfEnabled checks the recipient's push preferences and sends to all their devices if enabled.
func (s *Service) sendPushIfEnabled(ctx context.Context, recipientId int, body string, notificationType models.NotificationType, identifier int) {
	props, err := s.userRepository.GetUserDisplayProperties(ctx, recipientId)
	if err != nil || props == nil {
		return
	}

	prefs := props.PushPreferences
	if prefs == nil {
		return
	}

	var enabled bool
	switch notificationType {
	case models.NotificationTypeComment:
		enabled = prefs.Comments
	case models.NotificationTypeMention:
		enabled = prefs.Mentions
	case models.NotificationTypeFollowers:
		enabled = prefs.Followers
	}

	if !enabled {
		return
	}

	devices, err := s.notificationRepository.GetDeviceTokensForUser(ctx, recipientId)
	if err != nil || len(devices) == 0 {
		return
	}

	for _, device := range devices {
		n := apns.Notification{
			Payload: apns.NotificationPayload{
				Aps: apns.Aps{
					Alert: apns.Alert{
						Title: "Splajompy",
						Body:  body,
					},
					Badge:     0,
					Timestamp: time.Now().Unix(),
				},
				Type:       notificationType,
				Identifier: identifier,
			},
			DeviceToken: device,
		}
		_ = s.apnsClient.Push(ctx, &n)
	}
}

func (s *Service) buildLikedMessage(ctx context.Context, userIds []int, isComment bool) (*string, error) {
	users := []models.PublicUser{}
	for _, userId := range userIds[:min(3, len(userIds))] {
		user, err := s.userRepository.GetUserById(ctx, userId)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	// i hate this
	var noun string
	if isComment {
		noun = "comment"
	} else {
		noun = "post"
	}

	if len(userIds) == 1 {
		return new(fmt.Sprintf("@%s liked your %s.", users[0].Username, noun)), nil
	}

	if len(userIds) == 2 {
		return new(fmt.Sprintf("@%s and @%s liked your %s.", users[0].Username, users[1].Username, noun)), nil
	}

	if len(userIds) == 3 {
		return new(fmt.Sprintf("@%s, @%s, and @%s liked your %s.", users[0].Username, users[1].Username, users[2].Username, noun)), nil
	}

	message := fmt.Sprintf("@%s, @%s, @%s, and others liked your %s.", users[0].Username, users[1].Username, users[2].Username, noun)
	return &message, nil
}

func (s *Service) RegisterDeviceToken(ctx context.Context, userId int, deviceToken string) error {
	return s.notificationRepository.InsertDeviceToken(ctx, userId, deviceToken)
}
