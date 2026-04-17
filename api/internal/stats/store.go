package stats

import (
	"context"

	"splajompy.com/api/v2/internal/db/queries"
)

type Store struct {
	querier queries.Querier
}

// GetTotalPosts returns the total number of posts in the system
func (r Store) GetTotalPosts(ctx context.Context) (int64, error) {
	return r.querier.GetTotalPosts(ctx)
}

// GetTotalComments returns the total number of comments in the system
func (r Store) GetTotalComments(ctx context.Context) (int64, error) {
	return r.querier.GetTotalComments(ctx)
}

// GetTotalLikes returns the total number of likes in the system
func (r Store) GetTotalLikes(ctx context.Context) (int64, error) {
	return r.querier.GetTotalLikes(ctx)
}

// GetTotalFollows returns the total number of follow relationships in the system
func (r Store) GetTotalFollows(ctx context.Context) (int64, error) {
	return r.querier.GetTotalFollows(ctx)
}

// GetTotalUsers returns the total number of users in the system
func (r Store) GetTotalUsers(ctx context.Context) (int64, error) {
	return r.querier.GetTotalUsers(ctx)
}

// GetTotalNotifications returns the total number of notifications in the system
func (r Store) GetTotalNotifications(ctx context.Context) (int64, error) {
	return r.querier.GetTotalNotifications(ctx)
}

// NewDBStatsRepository creates a new stats repository
func NewDBStatsRepository(querier queries.Querier) Store {
	return Store{
		querier: querier,
	}
}
