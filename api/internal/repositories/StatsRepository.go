package repositories

import (
	"context"

	"splajompy.com/api/v2/internal/db/queries"
)

type StatsRepository interface {
	GetTotalPosts(ctx context.Context) (int64, error)
	GetTotalComments(ctx context.Context) (int64, error)
	GetTotalLikes(ctx context.Context) (int64, error)
	GetTotalFollows(ctx context.Context) (int64, error)
}

type DBStatsRepository struct {
	querier queries.Querier
}

// GetTotalPosts returns the total number of posts in the system
func (r DBStatsRepository) GetTotalPosts(ctx context.Context) (int64, error) {
	return r.querier.GetTotalPosts(ctx)
}

// GetTotalComments returns the total number of comments in the system
func (r DBStatsRepository) GetTotalComments(ctx context.Context) (int64, error) {
	return r.querier.GetTotalComments(ctx)
}

// GetTotalLikes returns the total number of likes in the system
func (r DBStatsRepository) GetTotalLikes(ctx context.Context) (int64, error) {
	return r.querier.GetTotalLikes(ctx)
}

// GetTotalFollows returns the total number of follow relationships in the system
func (r DBStatsRepository) GetTotalFollows(ctx context.Context) (int64, error) {
	return r.querier.GetTotalFollows(ctx)
}

// NewDBStatsRepository creates a new stats repository
func NewDBStatsRepository(querier queries.Querier) StatsRepository {
	return &DBStatsRepository{
		querier: querier,
	}
}
