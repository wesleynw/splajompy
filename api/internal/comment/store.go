package comment

import (
	"context"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type Store struct {
	querier queries.Querier
}

// AddCommentToPost adds a new comment to a post
func (r Store) AddCommentToPost(ctx context.Context, userId int, postId int, content string, facets db.Facets) (queries.Comment, error) {
	return r.querier.AddCommentToPost(ctx, queries.AddCommentToPostParams{
		PostID: postId,
		UserID: userId,
		Text:   content,
		Facets: facets,
	})
}

func (r Store) GetCommentById(ctx context.Context, commentId int) (queries.Comment, error) {
	return r.querier.GetCommentById(ctx, commentId)
}

// GetCommentsByPostId retrieves all comments for a specific post, excluding comments from users blocked by userId
func (r Store) GetCommentsByPostId(ctx context.Context, postId int, userId int) ([]queries.GetCommentsByPostIdRow, error) {
	return r.querier.GetCommentsByPostId(ctx, queries.GetCommentsByPostIdParams{
		PostID: postId,
		UserID: userId,
	})
}

// IsCommentLikedByUser checks if a comment is liked by a specific user
func (r Store) IsCommentLikedByUser(ctx context.Context, userId int, postId int, commentId int) (bool, error) {
	return r.querier.GetIsLikedByUser(ctx, queries.GetIsLikedByUserParams{
		UserID:    userId,
		PostID:    postId,
		CommentID: &commentId,
		Column4:   false,
	})
}

// DeleteComment deletes a comment by ID
func (r Store) DeleteComment(ctx context.Context, commentId int) error {
	return r.querier.DeleteComment(ctx, commentId)
}

// GetUserById retrieves a user by their ID
func (r Store) GetUserById(ctx context.Context, userId int) (queries.User, error) {
	return r.querier.GetUserById(ctx, userId)
}

func (r Store) InsertImage(ctx context.Context, commentId int, height int, width int, url string, displayOrder int) (*queries.Image, error) {
	image, err := r.querier.InsertImage(ctx, queries.InsertImageParams{
		Height:       height,
		Width:        width,
		ImageBlobUrl: url,
	})
	if err != nil {
		return nil, err
	}

	err = r.querier.AttachImageToComment(ctx, queries.AttachImageToCommentParams{
		CommentID: commentId,
		ImageID:   image.ImageID,
	})
	if err != nil {
		return nil, err
	}

	return &image, nil
}

func (r *Store) GetImagesByCommentId(ctx context.Context, commentId int) ([]queries.Image, error) {
	return r.querier.GetImagesByCommentId(ctx, commentId)
}

// NewStore creates a new comment repository
func NewStore(querier queries.Querier) *Store {
	return &Store{
		querier: querier,
	}
}
