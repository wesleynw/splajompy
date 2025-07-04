package service

import (
	"context"
	"errors"
	"fmt"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
)

type UserService struct {
	userRepository         repositories.UserRepository
	notificationRepository repositories.NotificationRepository
}

func NewUserService(userRepository repositories.UserRepository, notificationRepository repositories.NotificationRepository) *UserService {
	return &UserService{
		userRepository:         userRepository,
		notificationRepository: notificationRepository,
	}
}

func (s *UserService) GetUserById(ctx context.Context, cUser models.PublicUser, userID int) (*models.DetailedUser, error) {
	dbUser, err := s.userRepository.GetUserById(ctx, userID)
	if err != nil {
		return nil, err
	}

	bio, _ := s.userRepository.GetBioForUser(ctx, userID)
	isFollowing, _ := s.userRepository.IsUserFollowingUser(ctx, cUser.UserID, userID)
	isFollower, _ := s.userRepository.IsUserFollowingUser(ctx, userID, cUser.UserID)
	isBlocking, _ := s.userRepository.IsUserBlockingUser(ctx, cUser.UserID, userID)

	mutuals, _ := s.userRepository.GetMutualConnectionsForUser(ctx, cUser.UserID, userID)
	if mutuals == nil {
		mutuals = []string{}
	}

	return &models.DetailedUser{
		UserID:      dbUser.UserID,
		Email:       dbUser.Email,
		Username:    dbUser.Username,
		CreatedAt:   dbUser.CreatedAt,
		Name:        dbUser.Name,
		Bio:         bio,
		IsFollowing: isFollowing,
		IsFollower:  isFollower,
		IsBlocking:  isBlocking,
		Mutuals:     mutuals,
	}, nil
}

func (s *UserService) GetUserByUsernamePrefix(ctx context.Context, prefix string, currentUserId int) (*[]models.PublicUser, error) {
	users, err := s.userRepository.GetUsersWithUsernameLike(ctx, prefix, 10, currentUserId)
	if err != nil {
		return nil, err
	}

	publicUsers := make([]models.PublicUser, 0)

	publicUsers = append(publicUsers, users...)

	return &publicUsers, nil
}

func (s *UserService) FollowUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	user, err := s.userRepository.GetUserById(ctx, userId)
	if err != nil {
		return err
	}

	if blocked, _ := s.userRepository.IsUserBlockingUser(ctx, userId, currentUser.UserID); blocked {
		return errors.New("user is blocked")
	}

	if err := s.userRepository.FollowUser(ctx, currentUser.UserID, userId); err != nil {
		return err
	}

	text := fmt.Sprintf("@%s started following you.", currentUser.Username)
	if facets, _ := repositories.GenerateFacets(ctx, s.userRepository, text); facets != nil {
		err := s.notificationRepository.InsertNotification(ctx, user.UserID, nil, nil, &facets, text, queries.NotificationTypeAnnouncement)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *UserService) UnfollowUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.userRepository.UnfollowUser(ctx, currentUser.UserID, userId)
}

func (s *UserService) UpdateProfile(ctx context.Context, userId int, name *string, bio *string) error {
	if name != nil {
		if err := s.userRepository.UpdateUserName(ctx, userId, *name); err != nil {
			return err
		}
	}
	if bio != nil {
		if err := s.userRepository.UpdateBio(ctx, userId, *bio); err != nil {
			return err
		}
	}
	return nil
}

func (s *UserService) IsBlockingUser(ctx context.Context, userId int, targetUserId int) (bool, error) {
	return s.userRepository.IsUserBlockingUser(ctx, userId, targetUserId)
}

func (s *UserService) BlockUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	err := s.userRepository.UnfollowUser(ctx, currentUser.UserID, userId)
	if err != nil {
		return err
	}

	err = s.userRepository.UnfollowUser(ctx, userId, currentUser.UserID)
	if err != nil {
		return err
	}

	return s.userRepository.BlockUser(ctx, currentUser.UserID, userId)
}

func (s *UserService) UnblockUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.userRepository.UnblockUser(ctx, currentUser.UserID, userId)
}
