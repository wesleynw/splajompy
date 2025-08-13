package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/resend/resend-go/v2"
	"splajompy.com/api/v2/internal/templates"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
)

type UserService struct {
	userRepository         repositories.UserRepository
	notificationRepository repositories.NotificationRepository
	emailService           *resend.Client
}

func NewUserService(userRepository repositories.UserRepository, notificationRepository repositories.NotificationRepository, emailClient *resend.Client) *UserService {
	return &UserService{
		userRepository:         userRepository,
		notificationRepository: notificationRepository,
		emailService:           emailClient,
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
		err := s.notificationRepository.InsertNotification(ctx, user.UserID, nil, nil, &facets, text, models.NotificationTypeFollowers)
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

func (s *UserService) RequestFeature(ctx context.Context, user models.PublicUser, text string) error {
	requestingUser, err := s.userRepository.GetUserById(ctx, user.UserID)
	if err != nil {
		return err
	}

	html, err := templates.GenerateFeatureRequestEmail(requestingUser.Username, text)
	if err != nil {
		return err
	}

	params := &resend.SendEmailRequest{
		From:    "Splajompy <no-reply@splajompy.com>",
		To:      []string{"wesleynw@pm.me"},
		Subject: fmt.Sprintf("@%s requested a feature", requestingUser.Username),
		Html:    html,
	}

	_, err = s.emailService.Emails.Send(params)
	return err
}

func (s *UserService) GetFollowersByUserId(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) (*[]models.DetailedUser, error) {
	
	followers, err := s.userRepository.GetFollowersByUserId(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	detailedUsers := make([]models.DetailedUser, 0)
	for _, follower := range followers {
		var name string
		if follower.Name.Valid {
			name = follower.Name.String
		}
		
		// Check if current user is following this follower
		isFollowing, _ := s.userRepository.IsUserFollowingUser(ctx, currentUser.UserID, int(follower.UserID))
		isFollower, _ := s.userRepository.IsUserFollowingUser(ctx, int(follower.UserID), currentUser.UserID)
		isBlocking, _ := s.userRepository.IsUserBlockingUser(ctx, currentUser.UserID, int(follower.UserID))
		
		detailedUsers = append(detailedUsers, models.DetailedUser{
			UserID:      int(follower.UserID),
			Email:       follower.Email,
			Username:    follower.Username,
			CreatedAt:   follower.CreatedAt.Time,
			Name:        name,
			Bio:         "", // Not needed for followers list
			IsFollowing: isFollowing,
			IsFollower:  isFollower,
			IsBlocking:  isBlocking,
			Mutuals:     []string{}, // Could add if needed
		})
	}

	return &detailedUsers, nil
}

func (s *UserService) GetFollowingByUserId(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) (*[]models.DetailedUser, error) {
	
	following, err := s.userRepository.GetFollowingByUserId(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	detailedUsers := make([]models.DetailedUser, 0)
	for _, follow := range following {
		var name string
		if follow.Name.Valid {
			name = follow.Name.String
		}
		
		// Check if current user is following this user
		isFollowing, _ := s.userRepository.IsUserFollowingUser(ctx, currentUser.UserID, int(follow.UserID))
		isFollower, _ := s.userRepository.IsUserFollowingUser(ctx, int(follow.UserID), currentUser.UserID)
		isBlocking, _ := s.userRepository.IsUserBlockingUser(ctx, currentUser.UserID, int(follow.UserID))
		
		detailedUsers = append(detailedUsers, models.DetailedUser{
			UserID:      int(follow.UserID),
			Email:       follow.Email,
			Username:    follow.Username,
			CreatedAt:   follow.CreatedAt.Time,
			Name:        name,
			Bio:         "", // Not needed for following list
			IsFollowing: isFollowing,
			IsFollower:  isFollower,
			IsBlocking:  isBlocking,
			Mutuals:     []string{}, // Could add if needed
		})
	}

	return &detailedUsers, nil
}
