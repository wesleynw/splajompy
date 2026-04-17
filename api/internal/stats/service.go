package stats

import (
	"context"
	"errors"

	"splajompy.com/api/v2/internal/models"
)

type Service struct {
	statsRepository Store
}

func NewService(statsRepository Store) *Service {
	return &Service{
		statsRepository: statsRepository,
	}
}

func (s *Service) GetAppStats(ctx context.Context) (*models.AppStats, error) {
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

	totalUsers, err := s.statsRepository.GetTotalUsers(ctx)
	if err != nil {
		return nil, errors.New("unable to retrieve total users")
	}

	totalNotifications, err := s.statsRepository.GetTotalNotifications(ctx)
	if err != nil {
		return nil, errors.New("unable to retrieve total notifications")
	}

	return &models.AppStats{
		TotalPosts:         totalPosts,
		TotalComments:      totalComments,
		TotalLikes:         totalLikes,
		TotalFollows:       totalFollows,
		TotalUsers:         totalUsers,
		TotalNotifications: totalNotifications,
	}, nil
}
