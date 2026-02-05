package repositories

import (
	"context"
	"errors"
	"regexp"
	"time"

	"github.com/jackc/pgx/v5"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/utilities"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
)

type DBUserRepository struct {
	querier queries.Querier
}

// GetUserById retrieves a user by their ID
func (r DBUserRepository) GetUserById(ctx context.Context, userId int) (models.PublicUser, error) {
	user, err := r.querier.GetUserById(ctx, userId)
	if err != nil {
		return models.PublicUser{}, err
	}

	return utilities.MapUserToPublicUser(user), nil
}

// GetUserByUsername retrieves a user by their username
func (r DBUserRepository) GetUserByUsername(ctx context.Context, username string) (models.PublicUser, error) {
	user, err := r.querier.GetUserByUsername(ctx, username)
	if err != nil {
		return models.PublicUser{}, err
	}

	return utilities.MapUserToPublicUser(user), nil
}

// GetUserByIdentifier retrieves a user by email or username
func (r DBUserRepository) GetUserByIdentifier(ctx context.Context, identifier string) (models.PublicUser, error) {
	user, err := r.querier.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return models.PublicUser{}, err
	}

	return utilities.MapUserToPublicUser(user), nil
}

// GetBioForUser retrieves a user's bio
func (r DBUserRepository) GetBioForUser(ctx context.Context, userId int) (string, error) {
	return r.querier.GetBioByUserId(ctx, userId)
}

// UpdateBio updates a user's bio
func (r DBUserRepository) UpdateBio(ctx context.Context, userId int, bio string) error {
	return r.querier.UpdateUserBio(ctx, queries.UpdateUserBioParams{
		UserID: userId,
		Text:   bio,
	})
}

// IsUserFollowingUser checks if a user is following another user
func (r DBUserRepository) IsUserFollowingUser(ctx context.Context, followerId int, followingId int) (bool, error) {
	return r.querier.GetIsUserFollowingUser(ctx, queries.GetIsUserFollowingUserParams{
		FollowerID:  followerId,
		FollowingID: followingId,
	})
}

// FollowUser makes a user follow another user
func (r DBUserRepository) FollowUser(ctx context.Context, followerId int, followingId int) error {
	return r.querier.InsertFollow(ctx, queries.InsertFollowParams{
		FollowerID:  followerId,
		FollowingID: followingId,
	})
}

// UnfollowUser makes a user unfollow another user
func (r DBUserRepository) UnfollowUser(ctx context.Context, followerId int, followingId int) error {
	return r.querier.DeleteFollow(ctx, queries.DeleteFollowParams{
		FollowerID:  followerId,
		FollowingID: followingId,
	})
}

// SearchUsername retrieves users with usernames matching a pattern
func (r DBUserRepository) SearchUsername(ctx context.Context, prefix string, limit int, currentUserId int) ([]models.PublicUser, error) {
	users, err := r.querier.UserSearchWithHeuristics(ctx, queries.UserSearchWithHeuristicsParams{
		Username:     prefix,
		Limit:        limit,
		TargetUserID: currentUserId,
	})
	if err != nil {
		return nil, err
	}

	publicUsers := make([]models.PublicUser, len(users))
	for i, user := range users {
		user, err := r.querier.GetUserById(ctx, user.UserID)
		if err != nil {
			return nil, err
		}
		publicUser := utilities.MapUserToPublicUser(user)

		// Check if this user is a friend of the current user
		isFriend, err := r.querier.GetIsUserFriend(ctx, queries.GetIsUserFriendParams{
			UserID:       currentUserId,
			TargetUserID: user.UserID,
		})
		if err == nil {
			publicUser.IsFriend = &isFriend
		}

		publicUsers[i] = publicUser
	}

	return publicUsers, nil
}

// UpdateUserName updates a user's name
func (r DBUserRepository) UpdateUserName(ctx context.Context, userId int, newName string) error {
	return r.querier.UpdateUserName(ctx, queries.UpdateUserNameParams{
		UserID: userId,
		Name:   pgtype.Text{String: newName, Valid: true},
	})
}

// GetUserDisplayProperties retrieves a user's display properties
func (r DBUserRepository) GetUserDisplayProperties(ctx context.Context, userId int) (*db.UserDisplayProperties, error) {
	user, err := r.querier.GetUserById(ctx, userId)
	if err != nil {
		return nil, err
	}
	return user.UserDisplayProperties, nil
}

// UpdateUserDisplayProperties updates a user's display properties
func (r DBUserRepository) UpdateUserDisplayProperties(ctx context.Context, userId int, displayProperties *db.UserDisplayProperties) error {
	return r.querier.UpdateUserDisplayProperties(ctx, queries.UpdateUserDisplayPropertiesParams{
		UserID:                userId,
		UserDisplayProperties: displayProperties,
	})
}

// GetIsUsernameInUse checks if a username is already in use
func (r DBUserRepository) GetIsUsernameInUse(ctx context.Context, username string) (bool, error) {
	return r.querier.GetIsUsernameInUse(ctx, username)
}

// GetIsEmailInUse checks if an email is already in use
func (r DBUserRepository) GetIsEmailInUse(ctx context.Context, email string) (bool, error) {
	return r.querier.GetIsEmailInUse(ctx, email)
}

// CreateUser creates a new user
func (r DBUserRepository) CreateUser(ctx context.Context, username string, email string, password string, referralCode string) (models.PublicUser, error) {
	user, err := r.querier.CreateUser(ctx, queries.CreateUserParams{
		Username:     username,
		Email:        email,
		Password:     password,
		ReferralCode: referralCode,
	})
	if err != nil {
		return models.PublicUser{}, err
	}

	return utilities.MapUserToPublicUser(user), nil
}

// GetVerificationCode retrieves a verification code for a user
func (r DBUserRepository) GetVerificationCode(ctx context.Context, userId int, code string) (queries.VerificationCode, error) {
	return r.querier.GetVerificationCode(ctx, queries.GetVerificationCodeParams{
		UserID: userId,
		Code:   code,
	})
}

// CreateVerificationCode creates a verification code for a user
func (r DBUserRepository) CreateVerificationCode(ctx context.Context, userId int, code string, expiresAt time.Time) error {
	return r.querier.CreateVerificationCode(ctx, queries.CreateVerificationCodeParams{
		UserID:    userId,
		Code:      code,
		ExpiresAt: pgtype.Timestamp{Time: expiresAt, Valid: true},
	})
}

// GetUserPasswordByIdentifier retrieves a user's password by email or username
func (r DBUserRepository) GetUserPasswordByIdentifier(ctx context.Context, identifier string) (string, error) {
	user, err := r.querier.GetUserWithPasswordByIdentifier(ctx, identifier)
	if err != nil {
		return "", err
	}

	return user.Password, nil
}

// CreateSession creates a new session for a user
func (r DBUserRepository) CreateSession(ctx context.Context, sessionId string, userId int, expiresAt time.Time) error {
	return r.querier.CreateSession(ctx, queries.CreateSessionParams{
		ID:        sessionId,
		UserID:    userId,
		ExpiresAt: pgtype.Timestamp{Time: expiresAt, Valid: true},
	})
}

func (r DBUserRepository) BlockUser(ctx context.Context, currentUserId int, targetUserId int) error {
	return r.querier.BlockUser(ctx, queries.BlockUserParams{
		UserID:       currentUserId,
		TargetUserID: targetUserId,
	})
}

func (r DBUserRepository) UnblockUser(ctx context.Context, currentUserId int, targetUserId int) error {
	return r.querier.UnblockUser(ctx, queries.UnblockUserParams{
		UserID:       currentUserId,
		TargetUserID: targetUserId,
	})
}

func (r DBUserRepository) IsUserBlockingUser(ctx context.Context, blockerId int, blockedId int) (bool, error) {
	return r.querier.GetIsUserBlockingUser(ctx, queries.GetIsUserBlockingUserParams{
		UserID:       blockerId,
		TargetUserID: blockedId,
	})
}

func (r DBUserRepository) MuteUser(ctx context.Context, currentUserId int, targetUserId int) error {
	return r.querier.MuteUser(ctx, queries.MuteUserParams{
		UserID:       currentUserId,
		TargetUserID: targetUserId,
	})
}

func (r DBUserRepository) UnmuteUser(ctx context.Context, currentUserId int, targetUserId int) error {
	return r.querier.UnmuteUser(ctx, queries.UnmuteUserParams{
		UserID:       currentUserId,
		TargetUserID: targetUserId,
	})
}

func (r DBUserRepository) IsUserMutingUser(ctx context.Context, muterId int, mutedId int) (bool, error) {
	return r.querier.GetIsUserMutingUser(ctx, queries.GetIsUserMutingUserParams{
		UserID:       muterId,
		TargetUserID: mutedId,
	})
}

func (r DBUserRepository) DeleteAccount(ctx context.Context, userId int) error {
	return r.querier.DeleteUserById(ctx, userId)
}

// GetMutualConnectionsForUser retrieves mutual connections between current user and target user
func (r DBUserRepository) GetMutualConnectionsForUser(ctx context.Context, currentUserId int, targetUserId int) ([]string, error) {
	return r.querier.GetMutualConnectionsForUser(ctx, queries.GetMutualConnectionsForUserParams{
		FollowerID:   currentUserId,
		FollowerID_2: targetUserId,
	})
}

func (r DBUserRepository) GetFollowersByUserId_old(ctx context.Context, userId int, limit int, offset int) ([]queries.GetFollowersByUserIdRow, error) {
	return r.querier.GetFollowersByUserId(ctx, queries.GetFollowersByUserIdParams{
		FollowingID: userId,
		Limit:       limit,
		Offset:      offset,
	})
}

func (r DBUserRepository) GetFollowingByUserId_old(ctx context.Context, userId int, limit int, offset int) ([]queries.GetFollowingByUserIdRow, error) {
	return r.querier.GetFollowingByUserId(ctx, queries.GetFollowingByUserIdParams{
		FollowerID: userId,
		Limit:      limit,
		Offset:     offset,
	})
}

func (r DBUserRepository) GetMutualsByUserId_old(ctx context.Context, currentUserId int, targetUserId int, limit int, offset int) ([]queries.GetMutualsByUserIdRow, error) {
	return r.querier.GetMutualsByUserId(ctx, queries.GetMutualsByUserIdParams{
		FollowerID:   currentUserId,
		FollowerID_2: targetUserId,
		Limit:        limit,
		Offset:       offset,
	})
}

func (r DBUserRepository) GetFollowingUserIds(ctx context.Context, userId int, limit int, before *time.Time) ([]int, error) {
	var beforeParam pgtype.Timestamptz
	if before != nil {
		beforeParam = pgtype.Timestamptz{Time: *before, Valid: true}
	}

	return r.querier.GetFollowingUserIds(ctx, queries.GetFollowingUserIdsParams{
		UserID: userId,
		Before: beforeParam,
		Limit:  limit,
	})
}

func (r DBUserRepository) GetMutualUserIds(ctx context.Context, userId int, targetUserId int, limit int, before *time.Time) ([]int, error) {
	var beforeParam pgtype.Timestamptz
	if before != nil {
		beforeParam = pgtype.Timestamptz{Time: *before, Valid: true}
	}

	return r.querier.GetMutualsByUserIdV2(ctx, queries.GetMutualsByUserIdV2Params{
		UserID:       userId,
		TargetUserID: targetUserId,
		Before:       beforeParam,
		Limit:        limit,
	})
}

func (r DBUserRepository) GetIsReferralCodeInUse(ctx context.Context, code string) (bool, error) {
	return r.querier.GetIsReferralCodeInUse(ctx, code)
}

func (r DBUserRepository) AddUserRelationship(ctx context.Context, userId int, targetUserId int) error {
	return r.querier.AddUserRelationship(ctx, queries.AddUserRelationshipParams{
		UserID:       userId,
		TargetUserID: targetUserId,
	})
}

func (r DBUserRepository) RemoveUserRelationship(ctx context.Context, userId int, targetUserId int) error {
	return r.querier.RemoveUserRelationship(ctx, queries.RemoveUserRelationshipParams{
		UserID:       userId,
		TargetUserID: targetUserId,
	})
}

func (r DBUserRepository) GetRelationshipByUserId(ctx context.Context, userId int, limit int, before *time.Time) ([]models.PublicUser, error) {
	var beforeParam pgtype.Timestamptz
	if before != nil {
		beforeParam = pgtype.Timestamptz{Time: *before, Valid: true}
	}

	users, err := r.querier.ListUserRelationships(ctx, queries.ListUserRelationshipsParams{
		UserID: userId,
		Limit:  limit,
		Before: beforeParam,
	})
	if err != nil {
		return nil, err
	}

	publicUsers := make([]models.PublicUser, len(users))
	for i, user := range users {
		publicUsers[i] = utilities.MapUserToPublicUser(user)
	}

	return publicUsers, nil
}

func (r DBUserRepository) GetRelationshipUserIds(ctx context.Context, userId int, limit int, before *time.Time) ([]int, error) {
	var beforeParam pgtype.Timestamptz
	if before != nil {
		beforeParam = pgtype.Timestamptz{Time: *before, Valid: true}
	}

	users, err := r.querier.ListUserRelationships(ctx, queries.ListUserRelationshipsParams{
		UserID: userId,
		Limit:  limit,
		Before: beforeParam,
	})
	if err != nil {
		return nil, err
	}

	userIds := make([]int, len(users))
	for i, user := range users {
		userIds[i] = user.UserID
	}

	return userIds, nil
}

func (r DBUserRepository) IsUserFriend(ctx context.Context, userId int, targetUserId int) (bool, error) {
	return r.querier.GetIsUserFriend(ctx, queries.GetIsUserFriendParams{
		UserID:       userId,
		TargetUserID: targetUserId,
	})
}

// NewDBUserRepository creates a new user repository
func NewDBUserRepository(querier queries.Querier) UserRepository {
	return &DBUserRepository{querier: querier}
}

func GenerateFacets(ctx context.Context, userRepository UserRepository, text string) (db.Facets, error) {
	re := regexp.MustCompile(`@([a-zA-Z0-9_.]+)`)
	matches := re.FindAllStringSubmatchIndex(text, -1)

	var facets db.Facets

	for _, match := range matches {
		start, end := match[0], match[1]
		username := text[start+1 : end]
		user, err := userRepository.GetUserByUsername(ctx, username)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return nil, err
		}
		facets = append(facets, db.Facet{
			Type:       "mention",
			UserId:     user.UserID,
			IndexStart: start,
			IndexEnd:   end,
		})
	}

	return facets, nil
}
