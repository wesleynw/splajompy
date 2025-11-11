package service

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db/queries"
)

type WrappedService struct {
	querier queries.Querier
}

func NewWrappedService(querier queries.Querier) *WrappedService {
	return &WrappedService{
		querier: querier,
	}
}

var fetchLimit = 50

type UserActivityData struct {
	ActivityCountCeiling int   `json:"activityCountCeiling"`
	Counts               []int `json:"counts"`
	MostActiveDayIndex   int   `json: mostActiveDayIndex`
}

func (s *WrappedService) GetUserActivityData(ctx context.Context, userId int) (*UserActivityData, error) {
	counts := make([]int, 365)
	var cursor *time.Time
	ceiling := 0
	mostActiveDayIndex := 0

	yearStart := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	yearEnd := time.Date(2025, 12, 31, 23, 59, 59, 0, time.UTC)

	// posts
	for {
		var timestamp pgtype.Timestamp
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}
		posts, err := s.querier.WrappedGetAllUserPostsWithCursor(ctx, queries.WrappedGetAllUserPostsWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, err
		}
		if len(posts) == 0 {
			break
		}

		var lastPost *queries.Post
		for _, post := range posts {
			if !post.CreatedAt.Time.Before(yearStart) && !post.CreatedAt.Time.After(yearEnd) {
				index := int(post.CreatedAt.Time.Sub(yearStart).Hours() / 24)
				if index >= 0 && index < 365 {
					counts[index]++
					if counts[index] > ceiling {
						ceiling = counts[index]
						mostActiveDayIndex = index
					}
				}
			}
			lastPost = &post
		}

		cursor = &lastPost.CreatedAt.Time
	}

	cursor = nil

	// comments
	for {
		var timestamp pgtype.Timestamp
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}
		comments, err := s.querier.WrappedGetAllUserCommentsWithCursor(ctx, queries.WrappedGetAllUserCommentsWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, err
		}
		if len(comments) == 0 {
			break
		}

		var lastComment *queries.Comment
		for _, comment := range comments {
			if !comment.CreatedAt.Time.Before(yearStart) && !comment.CreatedAt.Time.After(yearEnd) {
				index := int(comment.CreatedAt.Time.Sub(yearStart).Hours() / 24)
				if index >= 0 && index < 365 {
					counts[index]++
					if counts[index] > ceiling {
						ceiling = counts[index]
						mostActiveDayIndex = index
					}
				}
			}
			lastComment = &comment
		}

		cursor = &lastComment.CreatedAt.Time
	}

	cursor = nil

	// likes
	for {
		var timestamp pgtype.Timestamptz
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}
		likes, err := s.querier.WrappedGetAllUserLikesWithCursor(ctx, queries.WrappedGetAllUserLikesWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, err
		}
		if len(likes) == 0 {
			break
		}

		var lastLike *queries.Like
		for _, like := range likes {
			if !like.CreatedAt.Time.Before(yearStart) && !like.CreatedAt.Time.After(yearEnd) {
				index := int(like.CreatedAt.Time.Sub(yearStart).Hours() / 24)
				if index >= 0 && index < 365 {
					counts[index]++
					if counts[index] > ceiling {
						ceiling = counts[index]
						mostActiveDayIndex = index
					}
				}
			}
			lastLike = &like
		}

		cursor = &lastLike.CreatedAt.Time
	}

	return &UserActivityData{
		ActivityCountCeiling: ceiling,
		Counts:               counts,
		MostActiveDayIndex:   mostActiveDayIndex,
	}, nil
}
