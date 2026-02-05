package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/resend/resend-go/v3"
	"golang.org/x/sync/errgroup"
	"splajompy.com/api/v2/internal/db"
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
	isFriend, _ := s.userRepository.IsUserFriend(ctx, cUser.UserID, userID)

	mutuals, err := s.userRepository.GetMutualConnectionsForUser(ctx, cUser.UserID, userID)
	if err != nil {
		return nil, err
	}
	if mutuals == nil {
		mutuals = []string{}
	}

	return &models.DetailedUser{
		UserID:            dbUser.UserID,
		Email:             dbUser.Email,
		Username:          dbUser.Username,
		CreatedAt:         dbUser.CreatedAt,
		Name:              dbUser.Name,
		Bio:               bio,
		IsFollowing:       isFollowing,
		IsFollower:        isFollower,
		IsBlocking:        isBlocking,
		IsMuting:          isMuting,
		IsFriend:          isFriend,
		Mutuals:           mutuals,
		MutualCount:       len(mutuals),
		IsVerified:        dbUser.IsVerified,
		DisplayProperties: dbUser.DisplayProperties,
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

func (s *UserService) UpdateProfile(ctx context.Context, userId int, name *string, bio *string, displayProperties *models.UserDisplayProperties) error {
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
	if displayProperties != nil {
		// fetch current properties to preserve sensitive server-tracked fields
		currentProps, err := s.userRepository.GetUserDisplayProperties(ctx, userId)
		if err != nil {
			return err
		}

		var dbDisplayProperties db.UserDisplayProperties
		if currentProps != nil {
			dbDisplayProperties = *currentProps
		}

		// only update user-editable fields
		dbDisplayProperties.FontChoiceId = displayProperties.FontChoiceId

		if err := s.userRepository.UpdateUserDisplayProperties(ctx, userId, &dbDisplayProperties); err != nil {
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

	body, err := templates.GenerateSupportEmail(requestingUser.Username, text)
	if err != nil {
		return err
	}

	params := &resend.SendEmailRequest{
		From:    "Splajompy <no-reply@splajompy.com>",
		To:      []string{"wesleynw@pm.me"},
		Subject: fmt.Sprintf("Support request from @%s", requestingUser.Username),
		Text:    body,
	}

	_, err = s.emailService.Emails.Send(params)
	return err
}

// GetFollowersByUserId_old retrieves users that are following the specified user.
// Deprecated in favor of updated cursor based pagination in
func (s *UserService) GetFollowersByUserId_old(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) ([]models.DetailedUser, error) {
	followers, err := s.userRepository.GetFollowersByUserId_old(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(followers))
	for i, follower := range followers {
		userIDs[i] = follower.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIDs)
}

func (s *UserService) GetFollowingByUserId(ctx context.Context, user models.PublicUser, targetUserId int, limit int, before *time.Time) ([]models.DetailedUser, error) {
	users, err := s.userRepository.GetFollowingUserIds(ctx, targetUserId, limit, before)
	if err != nil {
		return nil, err
	}

	return s.fetchDetailedUsersFromIDs(ctx, user, users)
}

// GetFollowingByUserId retrieves users that the specified user is following.
// Deprecated Use GetFollowingByUserId instead
func (s *UserService) GetFollowingByUserId_old(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) ([]models.DetailedUser, error) {
	following, err := s.userRepository.GetFollowingByUserId_old(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(following))
	for i, follow := range following {
		userIDs[i] = follow.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIDs)
}

// GetMutualsByUserId_old retrieves users that both the current user and the target user follow.
//
// Deprecated: prefer GetMutualsByUserId
func (s *UserService) GetMutualsByUserId_old(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) ([]models.DetailedUser, error) {
	mutuals, err := s.userRepository.GetMutualsByUserId_old(ctx, currentUser.UserID, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(mutuals))
	for i, mutual := range mutuals {
		userIDs[i] = mutual.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIDs)
}

// GetMutualsByUserId returns users who are 'mutuals' with the current user and target user. That is, who follow both the current user and target user.
func (s *UserService) GetMutualsByUserId(ctx context.Context, user models.PublicUser, targetUserId int, limit int, before *time.Time) ([]models.DetailedUser, error) {
	users, err := s.userRepository.GetMutualUserIds(ctx, user.UserID, targetUserId, limit, before)
	if err != nil {
		return nil, err
	}

	return s.fetchDetailedUsersFromIDs(ctx, user, users)
}

// AddUserToCloseFriendsList creates a relationship to mark the given userId as close friend of the current user.
func (s UserService) AddUserToCloseFriendsList(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.userRepository.AddUserRelationship(ctx, currentUser.UserID, userId)
}

// RemoveUserFromCloseFriendsList destroys a relationship between the given userId and the current user.
func (s UserService) RemoveUserFromCloseFriendsList(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.userRepository.RemoveUserRelationship(ctx, currentUser.UserID, userId)
}

// GetCloseFriendsByUserId returns a list of users on the current users close friends list, using the creation date of the relationsthip as a cursor.
func (s UserService) GetCloseFriendsByUserId(ctx context.Context, currentUser models.PublicUser, limit int, before *time.Time) ([]models.DetailedUser, error) {
	userIds, err := s.userRepository.GetRelationshipUserIds(ctx, currentUser.UserID, limit, before)
	if err != nil {
		return nil, err
	}
	return s.fetchDetailedUsersFromIDs(ctx, currentUser, userIds)
}

// fetchDetailedUsersFromIDs concurrently fetches detailed user information for the given user IDs.
// It uses an errgroup to parallelize the individual GetUserById calls and returns all results
// once complete, or the first error encountered.
func (s *UserService) fetchDetailedUsersFromIDs(ctx context.Context, currentUser models.PublicUser, userIDs []int) ([]models.DetailedUser, error) {
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

	return detailedUsers, nil
}
