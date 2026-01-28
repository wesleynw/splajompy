package repositories

import (
	"context"
	"time"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
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

	SearchUsername(ctx context.Context, prefix string, limit int, currentUserId int) ([]models.PublicUser, error)

	UpdateUserName(ctx context.Context, userId int, newName string) error

	UpdateUserDisplayProperties(ctx context.Context, userId int, displayProperties *db.UserDisplayProperties) error

	GetIsUsernameInUse(ctx context.Context, username string) (bool, error)

	GetIsEmailInUse(ctx context.Context, email string) (bool, error)

	CreateUser(ctx context.Context, username string, email string, password string, referralCode string) (models.PublicUser, error)

	GetVerificationCode(ctx context.Context, userId int, code string) (queries.VerificationCode, error)

	CreateVerificationCode(ctx context.Context, userId int, code string, expiresAt time.Time) error

	GetUserPasswordByIdentifier(ctx context.Context, identifier string) (string, error)

	CreateSession(ctx context.Context, sessionId string, userId int, expiresAt time.Time) error

	BlockUser(ctx context.Context, currentUserId int, targetUserId int) error

	UnblockUser(ctx context.Context, currentUserId int, targetUserId int) error

	IsUserBlockingUser(ctx context.Context, blockerId int, blockedId int) (bool, error)

	MuteUser(ctx context.Context, currentUserId int, targetUserId int) error

	UnmuteUser(ctx context.Context, currentUserId int, targetUserId int) error

	IsUserMutingUser(ctx context.Context, muterId int, mutedId int) (bool, error)

	DeleteAccount(ctx context.Context, userId int) error

	GetMutualConnectionsForUser(ctx context.Context, currentUserId int, targetUserId int) ([]string, error)

	// Deprecated: Use GetFollowersByUserId instead (make a route that uses a cursor offset)
	GetFollowersByUserId_old(ctx context.Context, userId int, limit int, offset int) ([]queries.GetFollowersByUserIdRow, error)

	// Deprecated: Use GetFollowingByUserId instead
	GetFollowingByUserId_old(ctx context.Context, userId int, limit int, offset int) ([]queries.GetFollowingByUserIdRow, error)

	// GetMutualsByUserId returns a list of users who the current user has mutual connections with.
	GetMutualsByUserId_old(ctx context.Context, currentUserId int, targetUserId int, limit int, offset int) ([]queries.GetMutualsByUserIdRow, error)

	// GetFollowingByUserId returns a list of user ids for users who the given user follows
	GetFollowingUserIds(ctx context.Context, userId int, limit int, before *time.Time) ([]int, error)

	GetIsReferralCodeInUse(ctx context.Context, code string) (bool, error)

	// AddUserRelationship creates a user relationship (right now only "close friends")
	AddUserRelationship(ctx context.Context, userId int, targetUserId int) error

	// RemoveUserRelationship deletes a user relationship (right now only "close friends")
	RemoveUserRelationship(ctx context.Context, userId int, targetUserId int) error

	// GetCloseFriendsByUserId returns a list of user relationships, paginated by the timestamp they were created.
	GetRelationshipByUserId(ctx context.Context, userId int, limit int, before *time.Time) ([]models.PublicUser, error)
}
