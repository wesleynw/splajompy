package like

import (
	"context"

	"splajompy.com/api/v2/internal/db/queries"
)

type Store struct {
	querier queries.Querier
}

// AddLike adds a like to a post or comment
func (r Store) AddLike(ctx context.Context, userId int, postId int, commentId *int) error {
	return r.querier.AddLike(ctx, queries.AddLikeParams{
		PostID:    postId,
		CommentID: commentId,
		UserID:    userId,
	})
}

// RemoveLike removes a like from a post or comment
func (r Store) RemoveLike(ctx context.Context, userId int, postId int, commentId *int) error {
	return r.querier.RemoveLike(ctx, queries.RemoveLikeParams{
		PostID:    postId,
		UserID:    userId,
		Column3:   commentId == nil, // is_post
		CommentID: commentId,
	})
}

// IsLiked checks if a user has liked a post or comment
func (r Store) IsLiked(ctx context.Context, userId int, postId int, commentId *int) (bool, error) {
	return r.querier.GetIsLikedByUser(ctx, queries.GetIsLikedByUserParams{
		UserID:    userId,
		PostID:    postId,
		CommentID: commentId,
		Column4:   commentId == nil,
	})
}

func (r Store) GetOtherPostLikes(ctx context.Context, postId int, currentUserId int) ([]queries.GetPostLikesRow, error) {
	return r.querier.GetPostLikes(ctx, queries.GetPostLikesParams{
		PostID: postId,
		UserID: currentUserId,
	})
}

// NewStore creates a new like repository
func NewStore(querier queries.Querier) Store {
	return Store{
		querier: querier,
	}
}
