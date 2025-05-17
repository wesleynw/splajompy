package repositories

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db/queries"
)

type CommentRepository interface {
	AddCommentToPost(ctx context.Context, userId int, postId int, content string) (queries.Comment, error)
	GetCommentsByPostId(ctx context.Context, postId int) ([]queries.GetCommentsByPostIdRow, error)
	IsCommentLikedByUser(ctx context.Context, userId int, postId int, commentId int) (bool, error)
	AddLikeToComment(ctx context.Context, userId int, postId int, commentId int) error
	RemoveLikeFromComment(ctx context.Context, userId int, postId int, commentId int) error
	GetUserById(ctx context.Context, userId int) (queries.GetUserByIdRow, error)
}

type DBCommentRepository struct {
	querier queries.Querier
}

// AddCommentToPost adds a new comment to a post
func (r DBCommentRepository) AddCommentToPost(ctx context.Context, userId int, postId int, content string) (queries.Comment, error) {
	return r.querier.AddCommentToPost(ctx, queries.AddCommentToPostParams{
		PostID: int32(postId),
		UserID: int32(userId),
		Text:   content,
	})
}

// GetCommentsByPostId retrieves all comments for a specific post
func (r DBCommentRepository) GetCommentsByPostId(ctx context.Context, postId int) ([]queries.GetCommentsByPostIdRow, error) {
	return r.querier.GetCommentsByPostId(ctx, int32(postId))
}

// IsCommentLikedByUser checks if a comment is liked by a specific user
func (r DBCommentRepository) IsCommentLikedByUser(ctx context.Context, userId int, postId int, commentId int) (bool, error) {
	return r.querier.GetIsLikedByUser(ctx, queries.GetIsLikedByUserParams{
		UserID:    int32(userId),
		PostID:    int32(postId),
		CommentID: pgtype.Int4{Int32: int32(commentId), Valid: true},
		Column4:   false,
	})
}

// AddLikeToComment adds a like to a comment
func (r DBCommentRepository) AddLikeToComment(ctx context.Context, userId int, postId int, commentId int) error {
	return r.querier.AddLike(ctx, queries.AddLikeParams{
		PostID:    int32(postId),
		CommentID: pgtype.Int4{Int32: int32(commentId), Valid: true},
		UserID:    int32(userId),
		IsPost:    false,
	})
}

// RemoveLikeFromComment removes a like from a comment
func (r DBCommentRepository) RemoveLikeFromComment(ctx context.Context, userId int, postId int, commentId int) error {
	return r.querier.RemoveLike(ctx, queries.RemoveLikeParams{
		PostID:    int32(postId),
		CommentID: pgtype.Int4{Int32: int32(commentId), Valid: true},
		UserID:    int32(userId),
		IsPost:    false,
	})
}

// GetUserById retrieves a user by their ID
func (r DBCommentRepository) GetUserById(ctx context.Context, userId int) (queries.GetUserByIdRow, error) {
	return r.querier.GetUserById(ctx, int32(userId))
}

// NewDBCommentRepository creates a new comment repository
func NewDBCommentRepository(querier queries.Querier) CommentRepository {
	return &DBCommentRepository{
		querier: querier,
	}
}
