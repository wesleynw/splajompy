package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/resend/resend-go/v2"
	"golang.org/x/sync/errgroup"
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
	isMuting, _ := s.userRepository.IsUserMutingUser(ctx, cUser.UserID, userID)

	mutuals, err := s.userRepository.GetMutualConnectionsForUser(ctx, cUser.UserID, userID)
	if err != nil {
		return nil, err
	}
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
		IsMuting:    isMuting,
		Mutuals:     mutuals,
		MutualCount: len(mutuals),
		IsVerified:  dbUser.IsVerified,
	}, nil
}

func (s *UserService) GetUserByUsernameSearch(ctx context.Context, prefix string, currentUserId int) (*[]models.PublicUser, error) {
	users, err := s.userRepository.SearchUsername(ctx, prefix, 10, currentUserId)
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
		err := s.notificationRepository.InsertNotification(ctx, user.UserID, nil, nil, &facets, text, models.NotificationTypeFollowers, &currentUser.UserID)
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

func (s *UserService) MuteUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.userRepository.MuteUser(ctx, currentUser.UserID, userId)
}

func (s *UserService) UnmuteUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.userRepository.UnmuteUser(ctx, currentUser.UserID, userId)
}

func (s *UserService) IsMutingUser(ctx context.Context, userId int, targetUserId int) (bool, error) {
	return s.userRepository.IsUserMutingUser(ctx, userId, targetUserId)
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

// GetFollowersByUserId retrieves users that are following the specified user.
func (s *UserService) GetFollowersByUserId(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) (*[]models.DetailedUser, error) {
	followers, err := s.userRepository.GetFollowersByUserId(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(followers))
	for i, follower := range followers {
		userIDs[i] = follower.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIDs)
}

// GetFollowingByUserId retrieves users that the specified user is following.
func (s *UserService) GetFollowingByUserId(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) (*[]models.DetailedUser, error) {
	following, err := s.userRepository.GetFollowingByUserId(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(following))
	for i, follow := range following {
		userIDs[i] = follow.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIDs)
}

// GetMutualsByUserId retrieves users that both the current user and the target user follow.
func (s *UserService) GetMutualsByUserId(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) (*[]models.DetailedUser, error) {
	mutuals, err := s.userRepository.GetMutualsByUserId(ctx, currentUser.UserID, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(mutuals))
	for i, mutual := range mutuals {
		userIDs[i] = mutual.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIDs)
}

// fetchDetailedUsersFromIDs concurrently fetches detailed user information for the given user IDs.
// It uses an errgroup to parallelize the individual GetUserById calls and returns all results
// once complete, or the first error encountered.
func (s *UserService) fetchDetailedUsersFromIDs(ctx context.Context, currentUser models.PublicUser, userIDs []int) (*[]models.DetailedUser, error) {
	detailedUsers := make([]models.DetailedUser, len(userIDs))
	g, ctx := errgroup.WithContext(ctx)

	for i, userID := range userIDs {
		g.Go(func() error {
			user, err := s.GetUserById(ctx, currentUser, userID)
			if err != nil {
				return err
			}
			detailedUsers[i] = *user
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		return nil, err
	}

	return &detailedUsers, nil
}
