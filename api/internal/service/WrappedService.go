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

type WrappedData struct {
	ActivityData        UserActivityData `json:"activityData"`
	PercentShareContent float32          `json:"percentShareContent"`
}
type UserActivityData struct {
	ActivityCountCeiling int            `json:"activityCountCeiling"`
	Counts               map[string]int `json:"counts"`
	MostActiveDay        string         `json:"mostActiveDay"`
}

func (s *WrappedService) CompileWrappedForUser(ctx context.Context, userId int) (*WrappedData, error) {
	var data WrappedData

	activity, err := s.getUserActivityData(ctx, userId)
	if err != nil {
		return nil, err
	}

	data.ActivityData = *activity

	percentShare, err := s.getPercentShareOfContent(ctx, userId)
	if err != nil {
		return nil, err
	}

	data.PercentShareContent = *percentShare

	return &data, nil
}

func (s *WrappedService) getUserActivityData(ctx context.Context, userId int) (*UserActivityData, error) {
	counts := make(map[string]int)
	yearStart := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	yearEnd := time.Date(2025, 12, 31, 23, 59, 0, 0, time.UTC)

	for d := yearStart; !d.After(yearEnd); d = d.AddDate(0, 0, 1) {
		counts[d.Format("2006-01-02")] = 0
	}

	var cursor *time.Time
	ceiling := 0
	mostActiveDay := ""

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
			if post.CreatedAt.Time.Year() == 2025 {
				dateKey := post.CreatedAt.Time.Format("2006-01-02")
				counts[dateKey]++
				if counts[dateKey] > ceiling {
					ceiling = counts[dateKey]
					mostActiveDay = dateKey
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
			if comment.CreatedAt.Time.Year() == 2025 {
				dateKey := comment.CreatedAt.Time.Format("2006-01-02")
				counts[dateKey]++
				if counts[dateKey] > ceiling {
					ceiling = counts[dateKey]
					mostActiveDay = dateKey
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
			if like.CreatedAt.Time.Year() == 2025 {
				dateKey := like.CreatedAt.Time.Format("2006-01-02")
				counts[dateKey]++
				if counts[dateKey] > ceiling {
					ceiling = counts[dateKey]
					mostActiveDay = dateKey
				}
			}
			lastLike = &like
		}
		cursor = &lastLike.CreatedAt.Time
	}

	return &UserActivityData{
		ActivityCountCeiling: ceiling,
		Counts:               counts,
		MostActiveDay:        mostActiveDay,
	}, nil
}

func (s *WrappedService) getPercentShareOfContent(ctx context.Context, userId int) (*float32, error) {
	userId = 33
	totalPosts, err := s.querier.GetTotalPosts(ctx)
	if err != nil {
		return nil, err
	}

	totalComments, err := s.querier.GetTotalComments(ctx)
	if err != nil {
		return nil, err
	}

	totalLikes, err := s.querier.GetTotalLikes(ctx)
	if err != nil {
		return nil, err
	}

	userPosts, err := s.querier.GetTotalPostsForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	userComments, err := s.querier.GetTotalCommentsForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	userLikes, err := s.querier.GetTotalLikesForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	const postWeight = 1
	const commentWeight = 0.2
	const likeWeight = 0.05

	totalWeight := float32(totalPosts)*postWeight + float32(totalComments)*commentWeight + float32(totalLikes)*likeWeight
	userWeight := float32(userPosts)*postWeight + float32(userComments)*commentWeight + float32(userLikes)*likeWeight

	proportion := (userWeight / totalWeight) * 100

	return &proportion, nil
}
