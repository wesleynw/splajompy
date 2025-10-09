package service

import (
	"context"
	"errors"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
)

type StatsService struct {
	statsRepository repositories.StatsRepository
}

func NewStatsService(statsRepository repositories.StatsRepository) *StatsService {
	return &StatsService{
		statsRepository: statsRepository,
	}
}

func (s *StatsService) GetAppStats(ctx context.Context) (*models.AppStats, error) {
	totalPosts, err := s.statsRepository.GetTotalPosts(ctx)
	if err != nil {
		return nil, errors.New("unable to retrieve total posts")
	}

	totalComments, err := s.statsRepository.GetTotalComments(ctx)
	if err != nil {
		return nil, errors.New("unable to retrieve total comments")
	}

	totalLikes, err := s.statsRepository.GetTotalLikes(ctx)
	if err != nil {
		return nil, errors.New("unable to retrieve total likes")
	}

	totalFollows, err := s.statsRepository.GetTotalFollows(ctx)
	if err != nil {
		return nil, errors.New("unable to retrieve total follows")
	}

	return &models.AppStats{
		TotalPosts:    totalPosts,
		TotalComments: totalComments,
		TotalLikes:    totalLikes,
		TotalFollows:  totalFollows,
	}, nil
}
