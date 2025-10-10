package repositories

import (
	"context"

	"splajompy.com/api/v2/internal/db/queries"
)

type LikeRepository interface {
	AddLike(ctx context.Context, userId int, postId int, commentId *int) error
	RemoveLike(ctx context.Context, userId int, postId int, commentId *int) error
	IsLiked(ctx context.Context, userId int, postId int, commentId *int) (bool, error)
	GetPostLikesFromFollowers(ctx context.Context, postId int, followerId int) ([]queries.GetPostLikesFromFollowersRow, error)
	HasLikesFromOthers(ctx context.Context, postId int, userIds []int) (bool, error)
}

type DBLikeRepository struct {
	querier queries.Querier
}

// AddLike adds a like to a post or comment
func (r DBLikeRepository) AddLike(ctx context.Context, userId int, postId int, commentId *int) error {
	return r.querier.AddLike(ctx, queries.AddLikeParams{
		PostID:    postId,
		CommentID: commentId,
		UserID:    userId,
	})
}

// RemoveLike removes a like from a post or comment
func (r DBLikeRepository) RemoveLike(ctx context.Context, userId int, postId int, commentId *int) error {
	return r.querier.RemoveLike(ctx, queries.RemoveLikeParams{
		PostID:    postId,
		UserID:    userId,
		Column3:   commentId == nil, // is_post
		CommentID: commentId,
	})
}

// IsLiked checks if a user has liked a post or comment
func (r DBLikeRepository) IsLiked(ctx context.Context, userId int, postId int, commentId *int) (bool, error) {
	return r.querier.GetIsLikedByUser(ctx, queries.GetIsLikedByUserParams{
		UserID:    userId,
		PostID:    postId,
		CommentID: commentId,
		Column4:   commentId == nil,
	})
}

// GetPostLikesFromFollowers retrieves likes on a post from users followed by a specific user
func (r DBLikeRepository) GetPostLikesFromFollowers(ctx context.Context, postId int, followerId int) ([]queries.GetPostLikesFromFollowersRow, error) {
	return r.querier.GetPostLikesFromFollowers(ctx, queries.GetPostLikesFromFollowersParams{
		PostID:     postId,
		FollowerID: followerId,
	})
}

// HasLikesFromOthers checks if a post has likes from users not in the provided list
func (r DBLikeRepository) HasLikesFromOthers(ctx context.Context, postId int, userIds []int) (bool, error) {
	return r.querier.HasLikesFromOthers(ctx, queries.HasLikesFromOthersParams{
		PostID:  postId,
		Column2: userIds,
	})
}

// NewDBLikeRepository creates a new like repository
func NewDBLikeRepository(querier queries.Querier) LikeRepository {
	return &DBLikeRepository{
		querier: querier,
	}
}
