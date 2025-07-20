package repositories

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type PostRepository interface {
	InsertPost(ctx context.Context, userId int, content string, facets db.Facets, attributes *db.Attributes) (*models.Post, error)
	DeletePost(ctx context.Context, postId int) error
	GetPostById(ctx context.Context, postId int) (*models.Post, error)
	IsPostLikedByUserId(ctx context.Context, userId int, postId int) (bool, error)
	GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error)
	GetAllImagesForUser(ctx context.Context, userId int) ([]queries.Image, error)
	InsertImage(ctx context.Context, postId int, height int, width int, url string, displayOrder int) (queries.Image, error)
	GetCommentCountForPost(ctx context.Context, postId int) (int, error)
	GetAllPostIds(ctx context.Context, limit int, offset int, currentUserId int) ([]int, error)
	GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int, error)
	GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int, error)
	GetPostIdsForMutualFeed(ctx context.Context, userId int, limit int, offset int) ([]queries.GetPostIdsForMutualFeedRow, error)
	GetPollVotesGrouped(ctx context.Context, postId int) ([]queries.GetPollVotesGroupedRow, error)
	GetUserVoteInPoll(ctx context.Context, postId int, userId int) (*int, error)
	InsertVote(ctx context.Context, postId int, userId int, optionIndex int) error
}

type DBPostRepository struct {
	querier queries.Querier
}

// InsertPost creates a new post
func (r DBPostRepository) InsertPost(ctx context.Context, userId int, content string, facets db.Facets, attributes *db.Attributes) (*models.Post, error) {
	var post, err = r.querier.InsertPost(ctx, queries.InsertPostParams{
		UserID:     int32(userId),
		Text:       pgtype.Text{String: content, Valid: true},
		Facets:     facets,
		Attributes: attributes,
	})
	if err != nil {
		return nil, err
	}

	mapped := utilities.MapPost(post)
	return &mapped, nil
}

// DeletePost removes a post by ID
func (r DBPostRepository) DeletePost(ctx context.Context, postId int) error {
	return r.querier.DeletePost(ctx, int32(postId))
}

// GetPostById retrieves a post by ID
func (r DBPostRepository) GetPostById(ctx context.Context, postId int) (*models.Post, error) {
	var dbPost, err = r.querier.GetPostById(ctx, int32(postId))
	if err != nil {
		return nil, err
	}
	return &models.Post{
		PostID:     int(dbPost.PostID),
		UserID:     dbPost.UserID,
		Text:       dbPost.Text.String,
		CreatedAt:  dbPost.CreatedAt.Time.UTC(),
		Facets:     dbPost.Facets,
		Attributes: dbPost.Attributes,
	}, nil
}

// IsPostLikedByUserId checks if a post is liked by a specific user
func (r DBPostRepository) IsPostLikedByUserId(ctx context.Context, userId int, postId int) (bool, error) {
	return r.querier.GetIsPostLikedByUser(ctx, queries.GetIsPostLikedByUserParams{
		PostID: int32(postId),
		UserID: int32(userId),
	})
}

// GetImagesForPost retrieves all images for a specific post
func (r DBPostRepository) GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error) {
	return r.querier.GetImagesByPostId(ctx, int32(postId))
}

// GetAllImagesForUser retrieves all images for a specific user
func (r DBPostRepository) GetAllImagesForUser(ctx context.Context, userId int) ([]queries.Image, error) {
	return r.querier.GetAllImagesByUserId(ctx, int32(userId))
}

// InsertImage adds a new image to a post
func (r DBPostRepository) InsertImage(ctx context.Context, postId int, height int, width int, url string, displayOrder int) (queries.Image, error) {
	return r.querier.InsertImage(ctx, queries.InsertImageParams{
		PostID:       int32(postId),
		Height:       int32(height),
		Width:        int32(width),
		ImageBlobUrl: url,
		DisplayOrder: int32(displayOrder),
	})
}

// GetCommentCountForPost returns the number of comments for a post
func (r DBPostRepository) GetCommentCountForPost(ctx context.Context, postId int) (int, error) {
	count, err := r.querier.GetCommentCountByPostID(ctx, int32(postId))
	return int(count), err
}

// GetAllPostIds retrieves IDs of all posts with pagination
func (r DBPostRepository) GetAllPostIds(ctx context.Context, limit int, offset int, currentUserId int) ([]int, error) {
	postIds32, err := r.querier.GetAllPostIds(ctx, queries.GetAllPostIdsParams{
		Limit:  int32(limit),
		Offset: int32(offset),
		UserID: int32(currentUserId),
	})
	if err != nil {
		return nil, err
	}

	postIds := make([]int, len(postIds32))
	for i, id := range postIds32 {
		postIds[i] = int(id)
	}
	return postIds, nil
}

// GetPostIdsForFollowing retrieves post IDs from users a specified user follows
func (r DBPostRepository) GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	postIds32, err := r.querier.GetPostIdsByFollowing(ctx, queries.GetPostIdsByFollowingParams{
		UserID: int32(userId),
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		return nil, err
	}

	postIds := make([]int, len(postIds32))
	for i, id := range postIds32 {
		postIds[i] = int(id)
	}
	return postIds, nil
}

// GetPostIdsForUser retrieves all post IDs for a specific user
func (r DBPostRepository) GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	postIds32, err := r.querier.GetPostsIdsByUserId(ctx, queries.GetPostsIdsByUserIdParams{
		UserID: int32(userId),
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		return nil, err
	}

	postIds := make([]int, len(postIds32))
	for i, id := range postIds32 {
		postIds[i] = int(id)
	}
	return postIds, nil
}

// GetPostIdsForMutualFeed retrieves post IDs for mutual feed with relationship metadata
func (r DBPostRepository) GetPostIdsForMutualFeed(ctx context.Context, userId int, limit int, offset int) ([]queries.GetPostIdsForMutualFeedRow, error) {
	return r.querier.GetPostIdsForMutualFeed(ctx, queries.GetPostIdsForMutualFeedParams{
		FollowerID: int32(userId),
		Limit:      int32(limit),
		Offset:     int32(offset),
	})
}

// GetPollVotesGrouped retrieves poll votes grouped by option index
func (r DBPostRepository) GetPollVotesGrouped(ctx context.Context, postId int) ([]queries.GetPollVotesGroupedRow, error) {
	return r.querier.GetPollVotesGrouped(ctx, int32(postId))
}

// GetUserVoteInPoll retrieves the user's vote for a specific poll
func (r DBPostRepository) GetUserVoteInPoll(ctx context.Context, postId int, userId int) (*int, error) {
	vote, err := r.querier.GetUserVoteInPoll(ctx, queries.GetUserVoteInPollParams{
		PostID: int32(postId),
		UserID: int32(userId),
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	result := int(vote)
	return &result, nil
}

// InsertVote adds a vote for a poll option
func (r DBPostRepository) InsertVote(ctx context.Context, postId int, userId int, optionIndex int) error {
	return r.querier.InsertVote(ctx, queries.InsertVoteParams{
		PostID:      int32(postId),
		UserID:      int32(userId),
		OptionIndex: int32(optionIndex),
	})
}

// NewDBPostRepository creates a new post repository instance
func NewDBPostRepository(querier queries.Querier) PostRepository {
	return &DBPostRepository{querier: querier}
}
