package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
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
	// First check if the post exists
	post, err := s.postRepo.GetPostById(ctx, postId)
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	// Add the comment
	comment, err := s.commentRepo.AddCommentToPost(ctx, int(currentUser.UserID), postId, content)
	if err != nil {
		return nil, errors.New("unable to create new comment")
	}

	// Create notification for the post owner
	err = s.notificationRepo.InsertNotification(
		ctx,
		int(post.UserID),
		&postId,
		fmt.Sprintf("%s commented on your post.", currentUser.Username),
	)
	if err != nil {
		return nil, errors.New("unable to create a new comment")
	}

	// Create and return the DetailedComment
	detailedComment := &models.DetailedComment{
		CommentID: comment.CommentID,
		PostID:    comment.PostID,
		UserID:    comment.UserID,
		Text:      comment.Text,
		CreatedAt: pgtype.Timestamp{Time: comment.CreatedAt.Time, Valid: true},
		User:      currentUser,
		IsLiked:   false, // New comments aren't liked by default
	}

	return detailedComment, nil
}

// GetCommentsByPostId retrieves all comments for a specific post with like status
func (s *CommentService) GetCommentsByPostId(ctx context.Context, currentUser models.PublicUser, postID int) ([]models.DetailedComment, error) {
	// Get all comments for the post
	dbComments, err := s.commentRepo.GetCommentsByPostId(ctx, postID)
	if err != nil {
		return nil, errors.New("unable to find comments")
	}

	// Transform the database rows into DetailedComment objects
	comments := make([]models.DetailedComment, 0, len(dbComments))
	for _, dbComment := range dbComments {
		// Get user information for each comment
		user, err := s.userRepo.GetUserById(ctx, int(dbComment.UserID))
		if err != nil {
			return nil, errors.New("unable to retrieve user associated with comment")
		}

		// Check if the comment is liked by the current user
		isLiked, err := s.commentRepo.IsCommentLikedByUser(
			ctx,
			int(currentUser.UserID),
			int(dbComment.PostID),
			int(dbComment.CommentID),
		)
		if err != nil {
			return nil, errors.New("unable to retrieve comment liked information")
		}

		// Create a DetailedComment with all information
		detailedComment := models.DetailedComment{
			CommentID: dbComment.CommentID,
			PostID:    dbComment.PostID,
			UserID:    dbComment.UserID,
			Text:      dbComment.Text,
			CreatedAt: pgtype.Timestamp{Time: dbComment.CreatedAt.Time, Valid: true},
			User:      user,
			IsLiked:   isLiked,
		}

		comments = append(comments, detailedComment)
	}

	return comments, nil
}

// AddLikeToCommentById adds a like to a comment
func (s *CommentService) AddLikeToCommentById(ctx context.Context, currentUser models.PublicUser, postID int, commentID int) error {
	err := s.commentRepo.AddLikeToComment(ctx, int(currentUser.UserID), postID, commentID)
	if err != nil {
		return errors.New("unable to add like to comment")
	}
	return nil
}

// RemoveLikeFromCommentById removes a like from a comment
func (s *CommentService) RemoveLikeFromCommentById(ctx context.Context, currentUser models.PublicUser, postID int, commentID int) error {
	err := s.commentRepo.RemoveLikeFromComment(ctx, int(currentUser.UserID), postID, commentID)
	if err != nil {
		return errors.New("unable to remove like from comment")
	}
	return nil
}
