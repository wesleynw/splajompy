package repositories

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"time"
)

type UserRepository interface {
	GetUserById(ctx context.Context, userId int) (models.PublicUser, error)
	GetUserByUsername(ctx context.Context, username string) (models.PublicUser, error)
	GetUserByIdentifier(ctx context.Context, identifier string) (models.PublicUser, error)
	GetBioForUser(ctx context.Context, userId int) (string, error)
	UpdateBio(ctx context.Context, userId int, bio string) error
	IsUserFollowingUser(ctx context.Context, followerId int, followingId int) (bool, error)
	FollowUser(ctx context.Context, followerId int, followingId int) error
	UnfollowUser(ctx context.Context, followerId int, followingId int) error
	GetUsersWithUsernameLike(ctx context.Context, prefix string, limit int) ([]models.PublicUser, error)
	UpdateUserName(ctx context.Context, userId int, newName string) error
	GetIsUsernameInUse(ctx context.Context, username string) (bool, error)
	GetIsEmailInUse(ctx context.Context, email string) (bool, error)
	CreateUser(ctx context.Context, username string, email string, password string) (models.PublicUser, error)
	GetVerificationCode(ctx context.Context, userId int, code string) (queries.VerificationCode, error)
	CreateVerificationCode(ctx context.Context, userId int, code string, expiresAt time.Time) error
	GetUserPasswordByIdentifier(ctx context.Context, identifier string) (string, error)
	CreateSession(ctx context.Context, sessionId string, userId int, expiresAt time.Time) error
}

type DBUserRepository struct {
	querier queries.Querier
}

// convertToPublicUser converts database user types to models.PublicUser
func convertToPublicUser(userID int32, email string, username string, createdAt pgtype.Timestamp, name pgtype.Text) models.PublicUser {
	return models.PublicUser{
		UserID:    userID,
		Email:     email,
		Username:  username,
		CreatedAt: createdAt,
		Name:      name,
	}
}

// GetUserById retrieves a user by their ID
func (r DBUserRepository) GetUserById(ctx context.Context, userId int) (models.PublicUser, error) {
	user, err := r.querier.GetUserById(ctx, int32(userId))
	if err != nil {
		return models.PublicUser{}, err
	}

	return convertToPublicUser(user.UserID, user.Email, user.Username, user.CreatedAt, user.Name), nil
}

// GetUserByUsername retrieves a user by their username
func (r DBUserRepository) GetUserByUsername(ctx context.Context, username string) (models.PublicUser, error) {
	user, err := r.querier.GetUserByUsername(ctx, username)
	if err != nil {
		return models.PublicUser{}, err
	}

	return convertToPublicUser(user.UserID, user.Email, user.Username, user.CreatedAt, user.Name), nil
}

// GetUserByIdentifier retrieves a user by email or username
func (r DBUserRepository) GetUserByIdentifier(ctx context.Context, identifier string) (models.PublicUser, error) {
	user, err := r.querier.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return models.PublicUser{}, err
	}

	return convertToPublicUser(user.UserID, user.Email, user.Username, user.CreatedAt, user.Name), nil
}

// GetBioForUser retrieves a user's bio
func (r DBUserRepository) GetBioForUser(ctx context.Context, userId int) (string, error) {
	return r.querier.GetBioByUserId(ctx, int32(userId))
}

// UpdateBio updates a user's bio
func (r DBUserRepository) UpdateBio(ctx context.Context, userId int, bio string) error {
	return r.querier.UpdateUserBio(ctx, queries.UpdateUserBioParams{
		UserID: int32(userId),
		Text:   bio,
	})
}

// IsUserFollowingUser checks if a user is following another user
func (r DBUserRepository) IsUserFollowingUser(ctx context.Context, followerId int, followingId int) (bool, error) {
	return r.querier.GetIsUserFollowingUser(ctx, queries.GetIsUserFollowingUserParams{
		FollowerID:  int32(followerId),
		FollowingID: int32(followingId),
	})
}

// FollowUser makes a user follow another user
func (r DBUserRepository) FollowUser(ctx context.Context, followerId int, followingId int) error {
	return r.querier.InsertFollow(ctx, queries.InsertFollowParams{
		FollowerID:  int32(followerId),
		FollowingID: int32(followingId),
	})
}

// UnfollowUser makes a user unfollow another user
func (r DBUserRepository) UnfollowUser(ctx context.Context, followerId int, followingId int) error {
	return r.querier.DeleteFollow(ctx, queries.DeleteFollowParams{
		FollowerID:  int32(followerId),
		FollowingID: int32(followingId),
	})
}

// GetUsersWithUsernameLike retrieves users with usernames matching a pattern
func (r DBUserRepository) GetUsersWithUsernameLike(ctx context.Context, prefix string, limit int) ([]models.PublicUser, error) {
	users, err := r.querier.GetUsernameLike(ctx, queries.GetUsernameLikeParams{
		Username: prefix + "%",
		Limit:    int32(limit),
	})
	if err != nil {
		return nil, err
	}

	publicUsers := make([]models.PublicUser, len(users))
	for i, user := range users {
		publicUsers[i] = models.PublicUser{
			UserID:    user.UserID,
			Email:     user.Email,
			Username:  user.Username,
			CreatedAt: pgtype.Timestamp(pgtype.Date{Time: user.CreatedAt.Time, Valid: true}),
			Name:      pgtype.Text{String: user.Name.String, Valid: true},
		}
	}

	return publicUsers, nil
}

// UpdateUserName updates a user's name
func (r DBUserRepository) UpdateUserName(ctx context.Context, userId int, newName string) error {
	return r.querier.UpdateUserName(ctx, queries.UpdateUserNameParams{
		UserID: int32(userId),
		Name:   pgtype.Text{String: newName, Valid: true},
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
func (r DBUserRepository) CreateUser(ctx context.Context, username string, email string, password string) (models.PublicUser, error) {
	user, err := r.querier.CreateUser(ctx, queries.CreateUserParams{
		Username: username,
		Email:    email,
		Password: password,
	})
	if err != nil {
		return models.PublicUser{}, err
	}

	return models.PublicUser{
		UserID:    user.UserID,
		Email:     user.Email,
		Username:  user.Username,
		CreatedAt: pgtype.Timestamp(pgtype.Date{Time: user.CreatedAt.Time, Valid: true}),
		Name:      pgtype.Text{String: user.Name.String, Valid: true},
	}, nil
}

// GetVerificationCode retrieves a verification code for a user
func (r DBUserRepository) GetVerificationCode(ctx context.Context, userId int, code string) (queries.VerificationCode, error) {
	return r.querier.GetVerificationCode(ctx, queries.GetVerificationCodeParams{
		UserID: int32(userId),
		Code:   code,
	})
}

// CreateVerificationCode creates a verification code for a user
func (r DBUserRepository) CreateVerificationCode(ctx context.Context, userId int, code string, expiresAt time.Time) error {
	return r.querier.CreateVerificationCode(ctx, queries.CreateVerificationCodeParams{
		UserID:    int32(userId),
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
		UserID:    int32(userId),
		ExpiresAt: pgtype.Timestamp{Time: expiresAt, Valid: true},
	})
}

// NewDBUserRepository creates a new user repository
func NewDBUserRepository(querier queries.Querier) UserRepository {
	return &DBUserRepository{querier: querier}
}
