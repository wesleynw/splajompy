package repositories

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db/queries"
)

type LikeRepository interface {
	AddLike(ctx context.Context, userId int, postId int, isPost bool) error
	RemoveLike(ctx context.Context, userId int, postId int, isPost bool) error
	GetPostLikesFromFollowers(ctx context.Context, postId int, followerId int) ([]queries.GetPostLikesFromFollowersRow, error)
	HasLikesFromOthers(ctx context.Context, postId int, userIds []int32) (bool, error)
}

type DBLikeRepository struct {
	querier queries.Querier
}

// AddLike adds a like to a post or comment
func (r DBLikeRepository) AddLike(ctx context.Context, userId int, postId int, isPost bool) error {
	// For posts, commentId should be null; for comments, we need a valid commentId
	// Since the interface only supports liking posts at this level, we'll set commentId to null
	var commentId pgtype.Int4
	if !isPost {
		// This shouldn't happen with the current interface, but it's here for future extensibility
		commentId = pgtype.Int4{Int32: 0, Valid: true}
	} else {
		commentId = pgtype.Int4{Int32: 0, Valid: false}
	}

	return r.querier.AddLike(ctx, queries.AddLikeParams{
		PostID:    int32(postId),
		CommentID: commentId,
		UserID:    int32(userId),
		IsPost:    isPost,
	})
}

// RemoveLike removes a like from a post or comment
func (r DBLikeRepository) RemoveLike(ctx context.Context, userId int, postId int, isPost bool) error {
	// For posts, commentId should be null; for comments we need a valid commentId
	// Since the interface only supports unliking posts at this level, we'll set commentId to null
	var commentId pgtype.Int4
	if !isPost {
		// This shouldn't happen with the current interface, but it's here for future extensibility
		commentId = pgtype.Int4{Int32: 0, Valid: true}
	} else {
		commentId = pgtype.Int4{Int32: 0, Valid: false}
	}

	return r.querier.RemoveLike(ctx, queries.RemoveLikeParams{
		PostID:    int32(postId),
		UserID:    int32(userId),
		IsPost:    isPost,
		CommentID: commentId,
	})
}

// GetPostLikesFromFollowers retrieves likes on a post from users followed by a specific user
func (r DBLikeRepository) GetPostLikesFromFollowers(ctx context.Context, postId int, followerId int) ([]queries.GetPostLikesFromFollowersRow, error) {
	return r.querier.GetPostLikesFromFollowers(ctx, queries.GetPostLikesFromFollowersParams{
		PostID:     int32(postId),
		FollowerID: int32(followerId),
	})
}

// HasLikesFromOthers checks if a post has likes from users not in the provided list
func (r DBLikeRepository) HasLikesFromOthers(ctx context.Context, postId int, userIds []int32) (bool, error) {
	return r.querier.HasLikesFromOthers(ctx, queries.HasLikesFromOthersParams{
		PostID:  int32(postId),
		Column2: userIds,
	})
}

// NewDBLikeRepository creates a new like repository
func NewDBLikeRepository(querier queries.Querier) LikeRepository {
	return &DBLikeRepository{
		querier: querier,
	}
}
