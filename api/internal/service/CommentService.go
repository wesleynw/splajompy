package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/utilities"
)

type CommentService struct {
	commentRepository      repositories.CommentRepository
	postRepository         repositories.PostRepository
	notificationRepository repositories.NotificationRepository
	userRepository         repositories.UserRepository
	likeRepository         repositories.LikeRepository
}

// NewCommentService creates a new comment service instance
func NewCommentService(
	commentRepo repositories.CommentRepository,
	postRepository repositories.PostRepository,
	notificationRepository repositories.NotificationRepository,
	userRepository repositories.UserRepository,
	likeRepository repositories.LikeRepository,
) *CommentService {
	return &CommentService{
		commentRepository:      commentRepo,
		postRepository:         postRepository,
		notificationRepository: notificationRepository,
		userRepository:         userRepository,
		likeRepository:         likeRepository,
	}
}

// AddCommentToPost adds a comment to a post and creates a notification
func (s *CommentService) AddCommentToPost(ctx context.Context, currentUser models.PublicUser, postId int, content string) (*models.DetailedComment, error) {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	commentFacets, err := repositories.GenerateFacets(ctx, s.userRepository, content)
	if err != nil {
		return nil, errors.New("unable to generate facets")
	}
	comment, err := s.commentRepository.AddCommentToPost(ctx, currentUser.UserID, postId, content, commentFacets)
	if err != nil {
		return nil, errors.New("unable to create new comment")
	}

	commentId := comment.CommentID

	if currentUser.UserID != post.UserID {
		text := fmt.Sprintf("@%s commented on your post.", currentUser.Username)
		notificationFacets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return nil, errors.New("unable to generate facets")
		}

		err = s.notificationRepository.InsertNotification(
			ctx,
			post.UserID,
			&postId,
			&commentId,
			&notificationFacets,
			text,
			models.NotificationTypeComment,
			nil,
		)
		if err != nil {
			return nil, errors.New("unable to create a new comment notification")
		}
	}

	// also send notifications to mentioned users
	usersToNotify := map[int]bool{}
	for _, facet := range commentFacets {
		if facet.UserId != post.UserID && facet.UserId != currentUser.UserID {
			usersToNotify[facet.UserId] = true
		}
	}

	for userId := range usersToNotify {
		text := fmt.Sprintf("@%s mentioned you in a comment.", currentUser.Username)
		notificationFacets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return nil, errors.New("unable to generate facets")
		}

		err = s.notificationRepository.InsertNotification(ctx, userId, &postId, &commentId, &notificationFacets, text, models.NotificationTypeMention, nil)
		if err != nil {
			return nil, errors.New("unable to create a new comment notification")
		}
	}

	detailedComment := utilities.MapComment(comment, currentUser, false)

	return &detailedComment, nil
}

// GetCommentsByPostId retrieves all comments for a specific post with like status
func (s *CommentService) GetCommentsByPostId(ctx context.Context, currentUser models.PublicUser, postID int) ([]models.DetailedComment, error) {

	dbComments, err := s.commentRepository.GetCommentsByPostId(ctx, postID)
	if err != nil {
		return nil, errors.New("unable to find comments")
	}

	comments := make([]models.DetailedComment, 0, len(dbComments))
	for _, dbComment := range dbComments {

		user, err := s.userRepository.GetUserById(ctx, dbComment.UserID)
		if err != nil {
			return nil, errors.New("unable to retrieve user associated with comment")
		}

		isLiked, err := s.likeRepository.IsLiked(
			ctx,
			currentUser.UserID,
			dbComment.PostID,
			&dbComment.CommentID,
		)
		if err != nil {
			return nil, errors.New("unable to retrieve comment liked information")
		}

		var comment = queries.Comment{
			CommentID: dbComment.CommentID,
			PostID:    dbComment.PostID,
			UserID:    dbComment.UserID,
			Text:      dbComment.Text,
			Facets:    dbComment.Facets,
			CreatedAt: dbComment.CreatedAt,
		}
		detailedComment := utilities.MapComment(comment, user, isLiked)

		comments = append(comments, detailedComment)
	}

	return comments, nil
}

// AddLikeToCommentById adds a like to a comment
func (s *CommentService) AddLikeToCommentById(ctx context.Context, currentUser models.PublicUser, postId int, commentId int) error {
	err := s.likeRepository.AddLike(ctx, currentUser.UserID, postId, &commentId)
	if err != nil {
		return errors.New("unable to add like to comment")
	}

	comment, err := s.commentRepository.GetCommentById(ctx, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	if currentUser.UserID != comment.UserID {
		text := fmt.Sprintf("@%s liked your comment.", currentUser.Username)
		facets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return err
		}
		err = s.notificationRepository.InsertNotification(ctx, comment.UserID, &postId, &commentId, &facets, text, models.NotificationTypeLike, nil)
		if err != nil {
			return errors.New("unable to create a new comment notification")
		}
	}

	return nil
}

// RemoveLikeFromCommentById removes the current user's like from a comment and
// deletes related notifications.
func (s *CommentService) RemoveLikeFromCommentById(ctx context.Context, user models.PublicUser, postId int, commentId int) error {
	err := s.likeRepository.RemoveLike(ctx, user.UserID, postId, &commentId)
	if err != nil {
		return errors.New("unable to remove like from comment")
	}

	comment, err := s.commentRepository.GetCommentById(ctx, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	notification, err := s.notificationRepository.FindUnreadLikeNotification(ctx, comment.UserID, postId, &commentId)
	if err == nil && notification != nil {
		if time.Since(notification.CreatedAt) <= 5*time.Minute {
			err = s.notificationRepository.DeleteNotificationById(ctx, notification.NotificationID)
			if err != nil {
				return errors.New("unable to remove liked comment")
			}
		}
	}

	return nil
}

// DeleteComment deletes a comment by ID if the current user owns it
func (s *CommentService) DeleteComment(ctx context.Context, currentUser models.PublicUser, commentId int) error {
	comment, err := s.commentRepository.GetCommentById(ctx, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	if comment.UserID != currentUser.UserID {
		return errors.New("unable to delete comment")
	}

	return s.commentRepository.DeleteComment(ctx, commentId)
}
