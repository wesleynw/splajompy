package user

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/resend/resend-go/v3"
	"golang.org/x/sync/errgroup"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/templates"
	"splajompy.com/api/v2/internal/utilities"

	"splajompy.com/api/v2/internal/models"
)

type Service struct {
	store                  Store
	notificationRepository notification.NotificationStore
	emailService           *resend.Client
}

func NewUserService(userRepository Store, notificationRepository notification.NotificationStore, emailClient *resend.Client) *Service {
	return &Service{
		store:                  userRepository,
		notificationRepository: notificationRepository,
		emailService:           emailClient,
	}
}

func (s *Service) GetUserById(ctx context.Context, currentUserId int, userID int) (*models.DetailedUser, error) {
	dbUser, err := s.store.GetUserById(ctx, userID)
	if err != nil {
		return nil, err
	}

	bio, _ := s.store.GetBioForUser(ctx, userID)
	isFollowing, _ := s.store.IsUserFollowingUser(ctx, currentUserId, userID)
	isFollower, _ := s.store.IsUserFollowingUser(ctx, userID, currentUserId)
	isBlocking, _ := s.store.IsUserBlockingUser(ctx, currentUserId, userID)
	isMuting, _ := s.store.IsUserMutingUser(ctx, currentUserId, userID)
	isFriend, _ := s.store.IsUserFriend(ctx, currentUserId, userID)

	mutuals, err := s.store.GetMutualConnectionsForUser(ctx, currentUserId, userID)
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

func (s *Service) GetUserByUsernameSearch(ctx context.Context, prefix string, currentUserId int) (*[]models.PublicUser, error) {
	users, err := s.store.SearchUsername(ctx, prefix, 10, currentUserId)
	if err != nil {
		return nil, err
	}

	publicUsers := make([]models.PublicUser, 0)
	publicUsers = append(publicUsers, users...)

	return &publicUsers, nil
}

func (s *Service) FollowUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	user, err := s.store.GetUserById(ctx, userId)
	if err != nil {
		return err
	}

	if blocked, _ := s.store.IsUserBlockingUser(ctx, userId, currentUser.UserID); blocked {
		return errors.New("user is blocked")
	}

	if err := s.store.FollowUser(ctx, currentUser.UserID, userId); err != nil {
		return err
	}

	text := fmt.Sprintf("@%s started following you.", currentUser.Username)
	if facets, _ := utilities.GenerateFacets(ctx, s.store, text); facets != nil {
		_, err := s.notificationRepository.InsertNotification(ctx, user.UserID, nil, nil, &facets, text, models.NotificationTypeFollowers, &currentUser.UserID)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) UnfollowUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.store.UnfollowUser(ctx, currentUser.UserID, userId)
}

func (s *Service) UpdateProfile(ctx context.Context, userId int, name *string, bio *string, displayProperties *models.UserDisplayProperties) error {
	if name != nil {
		if err := s.store.UpdateUserName(ctx, userId, *name); err != nil {
			return err
		}
	}
	if bio != nil {
		if err := s.store.UpdateBio(ctx, userId, *bio); err != nil {
			return err
		}
	}
	if displayProperties != nil {
		// fetch current properties to preserve sensitive server-tracked fields
		currentProps, err := s.store.GetUserDisplayProperties(ctx, userId)
		if err != nil {
			return err
		}

		var dbDisplayProperties db.UserDisplayProperties
		if currentProps != nil {
			dbDisplayProperties = *currentProps
		}

		// only update user-editable fields
		dbDisplayProperties.FontChoiceId = displayProperties.FontChoiceId

		if err := s.store.UpdateUserDisplayProperties(ctx, userId, &dbDisplayProperties); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) GetPushPreferences(ctx context.Context, userId int) (*db.PushPreferences, error) {
	props, err := s.store.GetUserDisplayProperties(ctx, userId)
	if err != nil {
		return nil, err
	}
	if props == nil {
		return nil, nil
	}
	return props.PushPreferences, nil
}

func (s *Service) UpdatePushPreferences(ctx context.Context, userId int, prefs db.PushPreferences) error {
	current, err := s.store.GetUserDisplayProperties(ctx, userId)
	if err != nil {
		return err
	}
	var props db.UserDisplayProperties
	if current != nil {
		props = *current
	}
	props.PushPreferences = &prefs
	return s.store.UpdateUserDisplayProperties(ctx, userId, &props)
}

func (s *Service) IsBlockingUser(ctx context.Context, userId int, targetUserId int) (bool, error) {
	return s.store.IsUserBlockingUser(ctx, userId, targetUserId)
}

// BlockUser blocks the target user
func (s *Service) BlockUser(ctx context.Context, currentUser models.PublicUser, targetUserId int) error {
	err := s.store.UnfollowUser(ctx, currentUser.UserID, targetUserId)
	if err != nil {
		return err
	}

	err = s.store.UnfollowUser(ctx, targetUserId, currentUser.UserID)
	if err != nil {
		return err
	}

	return s.store.BlockUser(ctx, currentUser.UserID, targetUserId)
}

func (s *Service) UnblockUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.store.UnblockUser(ctx, currentUser.UserID, userId)
}

func (s *Service) MuteUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.store.MuteUser(ctx, currentUser.UserID, userId)
}

func (s *Service) UnmuteUser(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.store.UnmuteUser(ctx, currentUser.UserID, userId)
}

func (s *Service) IsMutingUser(ctx context.Context, userId int, targetUserId int) (bool, error) {
	return s.store.IsUserMutingUser(ctx, userId, targetUserId)
}

func (s *Service) RequestFeature(ctx context.Context, user models.PublicUser, text string) error {
	requestingUser, err := s.store.GetUserById(ctx, user.UserID)
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
func (s *Service) GetFollowersByUserId_old(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) ([]models.DetailedUser, error) {
	followers, err := s.store.GetFollowersByUserId_old(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(followers))
	for i, follower := range followers {
		userIDs[i] = follower.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser.UserID, userIDs)
}

func (s *Service) GetFollowingByUserId(ctx context.Context, user models.PublicUser, targetUserId int, limit int, before *time.Time) (*models.PaginatedUserList, error) {
	userIDs, cursor, err := s.store.GetFollowingUserIds(ctx, targetUserId, limit, before)
	if err != nil {
		return nil, err
	}

	users, err := s.fetchDetailedUsersFromIDs(ctx, user.UserID, userIDs)
	if err != nil {
		return nil, err
	}

	return &models.PaginatedUserList{Users: users, NextCursor: cursor}, nil
}

// GetFollowingByUserId retrieves users that the specified user is following.
// Deprecated Use GetFollowingByUserId instead
func (s *Service) GetFollowingByUserId_old(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) ([]models.DetailedUser, error) {
	following, err := s.store.GetFollowingByUserId_old(ctx, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(following))
	for i, follow := range following {
		userIDs[i] = follow.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser.UserID, userIDs)
}

// GetMutualsByUserId_old retrieves users that both the current user and the target user follow.
//
// Deprecated: prefer GetMutualsByUserId
func (s *Service) GetMutualsByUserId_old(ctx context.Context, currentUser models.PublicUser, userId int, offset int, limit int) ([]models.DetailedUser, error) {
	mutuals, err := s.store.GetMutualsByUserId_old(ctx, currentUser.UserID, userId, limit, offset)
	if err != nil {
		return nil, err
	}

	userIDs := make([]int, len(mutuals))
	for i, mutual := range mutuals {
		userIDs[i] = mutual.UserID
	}

	return s.fetchDetailedUsersFromIDs(ctx, currentUser.UserID, userIDs)
}

// GetMutualsByUserId returns users who are 'mutuals' with the current user and target user. That is, who follow both the current user and target user.
func (s *Service) GetMutualsByUserId(ctx context.Context, user models.PublicUser, targetUserId int, limit int, before *time.Time) (*models.PaginatedUserList, error) {
	userIDs, cursor, err := s.store.GetMutualUserIds(ctx, user.UserID, targetUserId, limit, before)
	if err != nil {
		return nil, err
	}

	users, err := s.fetchDetailedUsersFromIDs(ctx, user.UserID, userIDs)
	if err != nil {
		return nil, err
	}

	return &models.PaginatedUserList{Users: users, NextCursor: cursor}, nil
}

// AddUserToCloseFriendsList creates a relationship to mark the given userId as close friend of the current user.
func (s Service) AddUserToCloseFriendsList(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.store.AddUserRelationship(ctx, currentUser.UserID, userId)
}

// RemoveUserFromCloseFriendsList destroys a relationship between the given userId and the current user.
func (s Service) RemoveUserFromCloseFriendsList(ctx context.Context, currentUser models.PublicUser, userId int) error {
	return s.store.RemoveUserRelationship(ctx, currentUser.UserID, userId)
}

// GetCloseFriendsByUserId returns a list of users on the current users close friends list, using the creation date of the relationsthip as a cursor.
func (s Service) GetCloseFriendsByUserId(ctx context.Context, currentUser models.PublicUser, limit int, before *time.Time) (*models.PaginatedUserList, error) {
	userIDs, cursor, err := s.store.GetRelationshipUserIds(ctx, currentUser.UserID, limit, before)
	if err != nil {
		return nil, err
	}

	users, err := s.fetchDetailedUsersFromIDs(ctx, currentUser.UserID, userIDs)
	if err != nil {
		return nil, err
	}

	return &models.PaginatedUserList{Users: users, NextCursor: cursor}, nil
}

func (s *Service) GetNotificationActors(ctx context.Context, currentUserId int, notificationId int, limit int, before *time.Time) (*models.PaginatedUserList, error) {
	notification, err := s.store.querier.GetNotificationById(ctx, notificationId)
	if err != nil {
		return nil, err
	}

	if notification.UserID != currentUserId {
		return nil, utilities.ErrUnauthorized
	}

	userIds, cursor, err := s.store.GetNotificationActorUserIds(ctx, notificationId, limit, before)
	if err != nil {
		return nil, err
	}

	users, err := s.fetchDetailedUsersFromIDs(ctx, currentUserId, userIds)
	if err != nil {
		return nil, err
	}

	return &models.PaginatedUserList{Users: users, NextCursor: cursor}, nil
}

// fetchDetailedUsersFromIDs concurrently fetches detailed user information for the given user IDs.
// It uses an errgroup to parallelize the individual GetUserById calls and returns all results
// once complete, or the first error encountered.
func (s *Service) fetchDetailedUsersFromIDs(ctx context.Context, currentUserId int, userIDs []int) ([]models.DetailedUser, error) {
	detailedUsers := make([]models.DetailedUser, len(userIDs))
	g, ctx := errgroup.WithContext(ctx)

	for i, userID := range userIDs {
		g.Go(func() error {
			user, err := s.GetUserById(ctx, currentUserId, userID)
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
