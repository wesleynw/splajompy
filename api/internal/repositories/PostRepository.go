package repositories

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type PostRepository interface {
	InsertPost(ctx context.Context, userId int, content string, facets db.Facets) (queries.Post, error)
	DeletePost(ctx context.Context, postId int) error
	GetPostById(ctx context.Context, postId int) (queries.Post, error)
	IsPostLikedByUserId(ctx context.Context, userId int, postId int) (bool, error)
	GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error)
	InsertImage(ctx context.Context, postId int, height int, width int, url string, displayOrder int) (queries.Image, error)
	GetCommentCountForPost(ctx context.Context, postId int) (int, error)
	GetAllPostIds(ctx context.Context, limit int, offset int) ([]int32, error)
	GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int32, error)
	GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int32, error)
}

type DBPostRepository struct {
	querier queries.Querier
}

// InsertPost creates a new post
func (r DBPostRepository) InsertPost(ctx context.Context, userId int, content string, facets db.Facets) (queries.Post, error) {
	return r.querier.InsertPost(ctx, queries.InsertPostParams{
		UserID: int32(userId),
		Text:   pgtype.Text{String: content, Valid: true},
		Facets: facets,
	})
}

// DeletePost removes a post by ID
func (r DBPostRepository) DeletePost(ctx context.Context, postId int) error {
	return r.querier.DeletePost(ctx, int32(postId))
}

// GetPostById retrieves a post by ID
func (r DBPostRepository) GetPostById(ctx context.Context, postId int) (queries.Post, error) {
	return r.querier.GetPostById(ctx, int32(postId))
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
func (r DBPostRepository) GetAllPostIds(ctx context.Context, limit int, offset int) ([]int32, error) {
	return r.querier.GetAllPostIds(ctx, queries.GetAllPostIdsParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
}

// GetPostIdsForFollowing retrieves post IDs from users a specified user follows
func (r DBPostRepository) GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int32, error) {
	return r.querier.GetPostIdsByFollowing(ctx, queries.GetPostIdsByFollowingParams{
		UserID: int32(userId),
		Limit:  int32(limit),
		Offset: int32(offset),
	})
}

// GetPostIdsForUser retrieves all post IDs for a specific user
func (r DBPostRepository) GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int32, error) {
	return r.querier.GetPostsIdsByUserId(ctx, queries.GetPostsIdsByUserIdParams{
		UserID: int32(userId),
		Limit:  int32(limit),
		Offset: int32(offset),
	})
}

// NewDBPostRepository creates a new post repository instance
func NewDBPostRepository(querier queries.Querier) PostRepository {
	return &DBPostRepository{querier: querier}
}
