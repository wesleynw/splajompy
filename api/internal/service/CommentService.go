package service

import (
	"context"
	"errors"
	"fmt"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/utilities"
	"time"
)

type CommentService struct {
	commentRepo      repositories.CommentRepository
	postRepo         repositories.PostRepository
	notificationRepo repositories.NotificationRepository
	userRepo         repositories.UserRepository
}

// NewCommentService creates a new comment service instance
func NewCommentService(
	commentRepo repositories.CommentRepository,
	postRepo repositories.PostRepository,
	notificationRepo repositories.NotificationRepository,
	userRepo repositories.UserRepository,
) *CommentService {
	return &CommentService{
		commentRepo:      commentRepo,
		postRepo:         postRepo,
		notificationRepo: notificationRepo,
		userRepo:         userRepo,
	}
}

// AddCommentToPost adds a comment to a post and creates a notification
func (s *CommentService) AddCommentToPost(ctx context.Context, currentUser models.PublicUser, postId int, content string) (*models.DetailedComment, error) {
	post, err := s.postRepo.GetPostById(ctx, postId)
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	commentFacets, err := repositories.GenerateFacets(ctx, s.userRepo, content)
	if err != nil {
		return nil, errors.New("unable to generate facets")
	}
	comment, err := s.commentRepo.AddCommentToPost(ctx, currentUser.UserID, postId, content, commentFacets)
	if err != nil {
		return nil, errors.New("unable to create new comment")
	}

	commentId := int(comment.CommentID)

	if currentUser.UserID != int(post.UserID) {
		text := fmt.Sprintf("@%s commented on your post.", currentUser.Username)
		notificationFacets, err := repositories.GenerateFacets(ctx, s.userRepo, text)
		if err != nil {
			return nil, errors.New("unable to generate facets")
		}

		err = s.notificationRepo.InsertNotification(
			ctx,
			int(post.UserID),
			&postId,
			&commentId,
			&notificationFacets,
			text,
			models.NotificationTypeComment,
		)
		if err != nil {
			return nil, errors.New("unable to create a new comment notification")
		}
	}

	// also send notifications to mentioned users
	for _, facet := range commentFacets {
		if facet.UserId != int(post.UserID) && facet.UserId != currentUser.UserID {
			text := fmt.Sprintf("@%s mentioned you in a comment.", currentUser.Username)
			notificationFacets, err := repositories.GenerateFacets(ctx, s.userRepo, text)
			if err != nil {
				return nil, errors.New("unable to generate facets")
			}

			err = s.notificationRepo.InsertNotification(ctx, facet.UserId, &postId, &commentId, &notificationFacets, text, models.NotificationTypeMention)
			if err != nil {
				return nil, errors.New("unable to create a new comment notification")
			}
		}
	}

	detailedComment := utilities.MapComment(comment, currentUser, false)

	return &detailedComment, nil
}

// GetCommentsByPostId retrieves all comments for a specific post with like status
func (s *CommentService) GetCommentsByPostId(ctx context.Context, currentUser models.PublicUser, postID int) ([]models.DetailedComment, error) {

	dbComments, err := s.commentRepo.GetCommentsByPostId(ctx, postID)
	if err != nil {
		return nil, errors.New("unable to find comments")
	}

	comments := make([]models.DetailedComment, 0, len(dbComments))
	for _, dbComment := range dbComments {

		user, err := s.userRepo.GetUserById(ctx, int(dbComment.UserID))
		if err != nil {
			return nil, errors.New("unable to retrieve user associated with comment")
		}

		isLiked, err := s.commentRepo.IsCommentLikedByUser(
			ctx,
			currentUser.UserID,
			int(dbComment.PostID),
			int(dbComment.CommentID),
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
	err := s.commentRepo.AddLikeToComment(ctx, currentUser.UserID, postId, commentId)
	if err != nil {
		return errors.New("unable to add like to comment")
	}

	comment, err := s.commentRepo.GetCommentById(ctx, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	if currentUser.UserID != int(comment.UserID) {
		text := fmt.Sprintf("@%s liked your comment.", currentUser.Username)
		facets, err := repositories.GenerateFacets(ctx, s.userRepo, text)
		if err != nil {
			return err
		}
		err = s.notificationRepo.InsertNotification(ctx, int(comment.UserID), &postId, &commentId, &facets, text, models.NotificationTypeLike)
		if err != nil {
			return errors.New("unable to create a new comment notification")
		}
	}

	return nil
}

// RemoveLikeFromCommentById removes the current user's like from a comment and
// deletes related notifications created within the last 5 minutes.
func (s *CommentService) RemoveLikeFromCommentById(ctx context.Context, user models.PublicUser, postId int, commentId int) error {
	err := s.commentRepo.RemoveLikeFromComment(ctx, user.UserID, postId, commentId)
	if err != nil {
		return errors.New("unable to remove like from comment")
	}

	comment, err := s.commentRepo.GetCommentById(ctx, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	notification, err := s.notificationRepo.FindUnreadLikeNotification(ctx, int(comment.UserID), postId, &commentId)
	if err == nil && notification != nil {
		if time.Since(notification.CreatedAt) <= 5*time.Minute {
			err = s.notificationRepo.DeleteNotificationById(ctx, notification.NotificationID)
			if err != nil {
				return errors.New("unable to remove liked comment")
			}
		}
	}

	return nil
}

// DeleteComment deletes a comment by ID if the current user owns it
func (s *CommentService) DeleteComment(ctx context.Context, currentUser models.PublicUser, commentId int) error {
	comment, err := s.commentRepo.GetCommentById(ctx, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	if int(comment.UserID) != currentUser.UserID {
		return errors.New("unable to delete comment")
	}

	return s.commentRepo.DeleteComment(ctx, commentId)
}
