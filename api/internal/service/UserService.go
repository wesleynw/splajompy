package service

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/utilities"
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
		return nil, errors.New("unable to find user")
	}

	bio, err := s.userRepository.GetBioForUser(ctx, userID)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, errors.New("unable to find bio")
	}

	isFollowing, err := s.userRepository.IsUserFollowingUser(ctx, int(cUser.UserID), userID)
	if err != nil {
		return nil, errors.New("unable to retrieve following information")
	}

	isFollower, err := s.userRepository.IsUserFollowingUser(ctx, userID, int(cUser.UserID))
	if err != nil {
		return nil, errors.New("unable to retrieve following information")
	}

	user := models.DetailedUser{
		UserID:      dbUser.UserID,
		Email:       dbUser.Email,
		Username:    dbUser.Username,
		CreatedAt:   dbUser.CreatedAt,
		Name:        dbUser.Name.String,
		Bio:         bio,
		IsFollowing: isFollowing,
		IsFollower:  isFollower,
	}

	return &user, nil
}

func (s *UserService) GetUserByUsernamePrefix(ctx context.Context, prefix string) (*[]models.PublicUser, error) {
	users, err := s.userRepository.GetUsersWithUsernameLike(ctx, prefix, 10)
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
		return errors.New("unable to find user")
	}

	err = s.userRepository.FollowUser(ctx, int(currentUser.UserID), userId)
	if err != nil {
		return err
	}

	text := fmt.Sprintf("@%s started following you.", currentUser.Username)
	facets, err := utilities.GenerateFacets(ctx, s.userRepository, text)
	if err != nil {
		return err
	}

	return s.notificationRepository.InsertNotification(ctx, int(user.UserID), nil, nil, &facets, text)
}

func (s *UserService) UnfollowUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	_, err := s.userRepository.GetUserById(ctx, userId)
	if err != nil {
		return errors.New("unable to find user")
	}

	return s.userRepository.UnfollowUser(ctx, int(currentUser.UserID), userId)
}

func (s *UserService) UpdateProfile(ctx context.Context, userId int, name *string, bio *string) error {
	_, err := s.userRepository.GetUserById(ctx, userId)
	if err != nil {
		return errors.New("unable to find user")
	}

	if name != nil {
		err = s.userRepository.UpdateUserName(ctx, userId, *name)
		if err != nil {
			return errors.New("unable to update user name")
		}
	}

	if bio != nil {
		err := s.userRepository.UpdateBio(ctx, userId, *bio)
		if err != nil {
			return errors.New("unable to update user bio")
		}
	}

	return nil
}
