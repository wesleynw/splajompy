package repositories

import (
	"context"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type CommentRepository interface {
	AddCommentToPost(ctx context.Context, userId int, postId int, content string, facets db.Facets) (queries.Comment, error)
	GetCommentById(ctx context.Context, commentId int) (queries.Comment, error)
	GetCommentsByPostId(ctx context.Context, postId int) ([]queries.GetCommentsByPostIdRow, error)
	IsCommentLikedByUser(ctx context.Context, userId int, postId int, commentId int) (bool, error)
	AddLikeToComment(ctx context.Context, userId int, postId int, commentId int) error
	RemoveLikeFromComment(ctx context.Context, userId int, postId int, commentId int) error
	DeleteComment(ctx context.Context, commentId int) error
	GetUserById(ctx context.Context, userId int) (queries.User, error)
}

type DBCommentRepository struct {
	querier queries.Querier
}

// AddCommentToPost adds a new comment to a post
func (r DBCommentRepository) AddCommentToPost(ctx context.Context, userId int, postId int, content string, facets db.Facets) (queries.Comment, error) {
	return r.querier.AddCommentToPost(ctx, queries.AddCommentToPostParams{
		PostID: postId,
		UserID: userId,
		Text:   content,
		Facets: facets,
	})
}

func (r DBCommentRepository) GetCommentById(ctx context.Context, commentId int) (queries.Comment, error) {
	return r.querier.GetCommentById(ctx, commentId)
}

// GetCommentsByPostId retrieves all comments for a specific post
func (r DBCommentRepository) GetCommentsByPostId(ctx context.Context, postId int) ([]queries.GetCommentsByPostIdRow, error) {
	return r.querier.GetCommentsByPostId(ctx, postId)
}

// IsCommentLikedByUser checks if a comment is liked by a specific user
func (r DBCommentRepository) IsCommentLikedByUser(ctx context.Context, userId int, postId int, commentId int) (bool, error) {
	return r.querier.GetIsLikedByUser(ctx, queries.GetIsLikedByUserParams{
		UserID:    userId,
		PostID:    postId,
		CommentID: &commentId,
		Column4:   false,
	})
}

// AddLikeToComment adds a like to a comment
func (r DBCommentRepository) AddLikeToComment(ctx context.Context, userId int, postId int, commentId int) error {
	return r.querier.AddLike(ctx, queries.AddLikeParams{
		PostID:    postId,
		CommentID: &commentId,
		UserID:    userId,
		IsPost:    false,
	})
}

// RemoveLikeFromComment removes a like from a comment
func (r DBCommentRepository) RemoveLikeFromComment(ctx context.Context, userId int, postId int, commentId int) error {
	return r.querier.RemoveLike(ctx, queries.RemoveLikeParams{
		PostID:    postId,
		CommentID: &commentId,
		UserID:    userId,
		IsPost:    false,
	})
}

// DeleteComment deletes a comment by ID
func (r DBCommentRepository) DeleteComment(ctx context.Context, commentId int) error {
	return r.querier.DeleteComment(ctx, commentId)
}

// GetUserById retrieves a user by their ID
func (r DBCommentRepository) GetUserById(ctx context.Context, userId int) (queries.User, error) {
	return r.querier.GetUserById(ctx, userId)
}

// NewDBCommentRepository creates a new comment repository
func NewDBCommentRepository(querier queries.Querier) CommentRepository {
	return &DBCommentRepository{
		querier: querier,
	}
}
