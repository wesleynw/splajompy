package service

import (
	"context"
	"errors"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
)

type UserService struct {
	queries *db.Queries
}

func NewUserService(queries *db.Queries) *UserService {
	return &UserService{
		queries: queries,
	}
}

func (s *UserService) GetUserById(ctx context.Context, cUser models.PublicUser, userID int) (*models.DetailedUser, error) {
	dbUser, err := s.queries.GetUserById(ctx, int32(userID))
	if err != nil {
		return nil, errors.New("unable to find user")
	}

	bio, err := s.queries.GetBioByUserId(ctx, int32(userID))
	if err != nil {
		return nil, errors.New("unable to find bio")
	}

	isFollowing, err := s.queries.GetIsUserFollowingUser(ctx, db.GetIsUserFollowingUserParams{FollowerID: cUser.UserID, FollowingID: int32(userID)})
	if err != nil {
		return nil, errors.New("unable to retrieve following information")
	}

	isFollower, err := s.queries.GetIsUserFollowingUser(ctx, db.GetIsUserFollowingUserParams{FollowerID: int32(userID), FollowingID: cUser.UserID})
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
