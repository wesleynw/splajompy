package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type PostRepository interface {
	InsertPost(ctx context.Context, userId int, content string, facets db.Facets, attributes *db.Attributes, visibilityType *models.VisibilityTypeEnum) (*models.Post, error)
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
	GetPostIdsByUserIdCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]int, error)
	GetPostIdsForMutualFeed(ctx context.Context, userId int, limit int, offset int) ([]queries.GetPostIdsForMutualFeedRow, error)
	GetAllPostIdsCursor(ctx context.Context, limit int, beforeTimestamp *time.Time, currentUserId int) ([]int, error)
	GetPostIdsForFollowingCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]int, error)
	GetPostIdsForMutualFeedCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]queries.GetPostIdsForMutualFeedCursorRow, error)
	GetPollVotesGrouped(ctx context.Context, postId int) ([]queries.GetPollVotesGroupedRow, error)
	GetUserVoteInPoll(ctx context.Context, postId int, userId int) (*int, error)
	InsertVote(ctx context.Context, postId int, userId int, optionIndex int) error
	PinPost(ctx context.Context, userId int, postId int) error
	UnpinPost(ctx context.Context, userId int) error
	GetPinnedPostId(ctx context.Context, userId int) (*int, error)
}

type DBPostRepository struct {
	querier queries.Querier
}

// InsertPost creates a new post
func (r DBPostRepository) InsertPost(ctx context.Context, userId int, content string, facets db.Facets, attributes *db.Attributes, visibilityType *models.VisibilityTypeEnum) (*models.Post, error) {
	var post, err = r.querier.InsertPost(ctx, queries.InsertPostParams{
		UserID:         userId,
		Text:           pgtype.Text{String: content, Valid: true},
		Facets:         facets,
		Attributes:     attributes,
		Visibilitytype: pgtype.Int4{Int32: int32(*visibilityType), Valid: visibilityType != nil},
	})
	if err != nil {
		return nil, err
	}

	mapped := utilities.MapPost(post)
	return &mapped, nil
}

// DeletePost removes a post by ID
func (r DBPostRepository) DeletePost(ctx context.Context, postId int) error {
	return r.querier.DeletePost(ctx, postId)
}

// GetPostById retrieves a post by ID
func (r DBPostRepository) GetPostById(ctx context.Context, postId int) (*models.Post, error) {
	var dbPost, err = r.querier.GetPostById(ctx, postId)
	if err != nil {
		return nil, err
	}
	return &models.Post{
		PostID:     dbPost.PostID,
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
		PostID: postId,
		UserID: userId,
	})
}

// GetImagesForPost retrieves all images for a specific post
func (r DBPostRepository) GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error) {
	return r.querier.GetImagesByPostId(ctx, postId)
}

// GetAllImagesForUser retrieves all images for a specific user
func (r DBPostRepository) GetAllImagesForUser(ctx context.Context, userId int) ([]queries.Image, error) {
	return r.querier.GetAllImagesByUserId(ctx, userId)
}

// InsertImage adds a new image to a post
func (r DBPostRepository) InsertImage(ctx context.Context, postId int, height int, width int, url string, displayOrder int) (queries.Image, error) {
	return r.querier.InsertImage(ctx, queries.InsertImageParams{
		PostID:       postId,
		Height:       height,
		Width:        width,
		ImageBlobUrl: url,
		DisplayOrder: displayOrder,
	})
}

// GetCommentCountForPost returns the number of comments for a post
func (r DBPostRepository) GetCommentCountForPost(ctx context.Context, postId int) (int, error) {
	count, err := r.querier.GetCommentCountByPostID(ctx, postId)
	return int(count), err
}

// GetAllPostIds retrieves IDs of all posts with pagination
func (r DBPostRepository) GetAllPostIds(ctx context.Context, limit int, offset int, currentUserId int) ([]int, error) {
	return r.querier.GetAllPostIds(ctx, queries.GetAllPostIdsParams{
		Limit:  limit,
		Offset: offset,
		UserID: currentUserId,
	})
}

// GetPostIdsForFollowing retrieves post IDs from users a specified user follows
func (r DBPostRepository) GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	return r.querier.GetPostIdsByFollowing(ctx, queries.GetPostIdsByFollowingParams{
		UserID: userId,
		Limit:  limit,
		Offset: offset,
	})
}

// GetPostIdsForUser retrieves all post IDs for a specific user
func (r DBPostRepository) GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	return r.querier.GetPostsIdsByUserId(ctx, queries.GetPostsIdsByUserIdParams{
		UserID: userId,
		Limit:  limit,
		Offset: offset,
	})
}

// GetPostIdsForMutualFeed retrieves post IDs for mutual feed with relationship metadata
func (r DBPostRepository) GetPostIdsForMutualFeed(ctx context.Context, userId int, limit int, offset int) ([]queries.GetPostIdsForMutualFeedRow, error) {
	return r.querier.GetPostIdsForMutualFeed(ctx, queries.GetPostIdsForMutualFeedParams{
		FollowerID: userId,
		Limit:      limit,
		Offset:     offset,
	})
}

// GetPollVotesGrouped retrieves poll votes grouped by option index
func (r DBPostRepository) GetPollVotesGrouped(ctx context.Context, postId int) ([]queries.GetPollVotesGroupedRow, error) {
	return r.querier.GetPollVotesGrouped(ctx, postId)
}

// GetUserVoteInPoll retrieves the user's vote for a specific poll
func (r DBPostRepository) GetUserVoteInPoll(ctx context.Context, postId int, userId int) (*int, error) {
	vote, err := r.querier.GetUserVoteInPoll(ctx, queries.GetUserVoteInPollParams{
		PostID: postId,
		UserID: userId,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	result := vote
	return &result, nil
}

// InsertVote adds a vote for a poll option
func (r DBPostRepository) InsertVote(ctx context.Context, postId int, userId int, optionIndex int) error {
	return r.querier.InsertVote(ctx, queries.InsertVoteParams{
		PostID:      postId,
		UserID:      userId,
		OptionIndex: optionIndex,
	})
}

// GetAllPostIdsCursor retrieves IDs of all posts using cursor-based pagination
func (r DBPostRepository) GetAllPostIdsCursor(ctx context.Context, limit int, beforeTimestamp *time.Time, currentUserId int) ([]int, error) {
	var timestamp pgtype.Timestamp
	if beforeTimestamp != nil {
		timestamp = pgtype.Timestamp{Time: *beforeTimestamp, Valid: true}
	}

	return r.querier.GetAllPostIdsCursor(ctx, queries.GetAllPostIdsCursorParams{
		Limit:   limit,
		Column2: timestamp,
		UserID:  currentUserId,
	})
}

// GetPostIdsForFollowingCursor retrieves post IDs from users a specified user follows using cursor-based pagination
func (r DBPostRepository) GetPostIdsForFollowingCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]int, error) {
	var timestamp pgtype.Timestamp
	if beforeTimestamp != nil {
		timestamp = pgtype.Timestamp{Time: *beforeTimestamp, Valid: true}
	}

	return r.querier.GetPostIdsByFollowingCursor(ctx, queries.GetPostIdsByFollowingCursorParams{
		UserID:  userId,
		Limit:   limit,
		Column3: timestamp,
	})
}

// GetPostIdsForMutualFeedCursor retrieves post IDs for mutual feed
func (r DBPostRepository) GetPostIdsForMutualFeedCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]queries.GetPostIdsForMutualFeedCursorRow, error) {
	var timestamp pgtype.Timestamp
	if beforeTimestamp != nil {
		timestamp = pgtype.Timestamp{Time: *beforeTimestamp, Valid: true}
	}

	return r.querier.GetPostIdsForMutualFeedCursor(ctx, queries.GetPostIdsForMutualFeedCursorParams{
		FollowerID: userId,
		Limit:      limit,
		Column3:    timestamp,
	})
}

// GetPostIdsByUserIdCursor retrieves post IDs for a specific user
func (r DBPostRepository) GetPostIdsByUserIdCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]int, error) {
	var timestamp pgtype.Timestamp
	if beforeTimestamp != nil {
		timestamp = pgtype.Timestamp{Time: *beforeTimestamp, Valid: true}
	}

	return r.querier.GetPostIdsByUserIdCursor(ctx, queries.GetPostIdsByUserIdCursorParams{
		UserID:  userId,
		Limit:   limit,
		Column3: timestamp,
	})
}

// PinPost sets a post as pinned for a user
func (r DBPostRepository) PinPost(ctx context.Context, userId int, postId int) error {
	return r.querier.PinPost(ctx, queries.PinPostParams{
		UserID:       userId,
		PinnedPostID: &postId,
	})
}

// UnpinPost removes the pinned post for a user
func (r DBPostRepository) UnpinPost(ctx context.Context, userId int) error {
	return r.querier.UnpinPost(ctx, userId)
}

// GetPinnedPostId retrieves the pinned post ID for a user
func (r DBPostRepository) GetPinnedPostId(ctx context.Context, userId int) (*int, error) {
	return r.querier.GetPinnedPostId(ctx, userId)
}

// NewDBPostRepository creates a new post repository instance
func NewDBPostRepository(querier queries.Querier) PostRepository {
	return &DBPostRepository{querier: querier}
}
