package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/utilities"
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

	facets, err := utilities.GenerateFacets(ctx, s.userRepo, content)
	if err != nil {
		return nil, errors.New("unable to generate facets")
	}
	comment, err := s.commentRepo.AddCommentToPost(ctx, int(currentUser.UserID), postId, content, facets)
	if err != nil {
		return nil, errors.New("unable to create new comment")
	}

	commentId := int(comment.CommentID)
	text := fmt.Sprintf("@%s commented on your post.", currentUser.Username)
	facets, err = utilities.GenerateFacets(ctx, s.userRepo, text)
	if err != nil {
		return nil, errors.New("unable to generate facets")
	}

	err = s.notificationRepo.InsertNotification(
		ctx,
		int(post.UserID),
		&postId,
		&commentId,
		&facets,
		text,
	)
	if err != nil {
		return nil, errors.New("unable to create a new comment")
	}

	detailedComment := &models.DetailedComment{
		CommentID: comment.CommentID,
		PostID:    comment.PostID,
		UserID:    comment.UserID,
		Text:      comment.Text,
		Facets:    facets,
		CreatedAt: pgtype.Timestamp{Time: comment.CreatedAt.Time, Valid: true},
		User:      currentUser,
		IsLiked:   false,
	}

	return detailedComment, nil
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
			int(currentUser.UserID),
			int(dbComment.PostID),
			int(dbComment.CommentID),
		)
		if err != nil {
			return nil, errors.New("unable to retrieve comment liked information")
		}

		detailedComment := models.DetailedComment{
			CommentID: dbComment.CommentID,
			PostID:    dbComment.PostID,
			UserID:    dbComment.UserID,
			Text:      dbComment.Text,
			Facets:    dbComment.Facets,
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
