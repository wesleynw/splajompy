package models

import (
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
)

type DetailedPost struct {
	Post         db.Post
	User         db.GetUserByIdRow
	IsLiked      bool
	Images       []db.Image
	CommentCount int
}

type DetailedComment struct {
	CommentID int32
	PostID    int32
	UserID    int32
	Text      string
	CreatedAt pgtype.Timestamp
	User      PublicUser
	IsLiked   bool
}

type PublicUser = db.GetUserByIdentifierRow

type DetailedUser struct {
	UserID      int32
	Email       string
	Username    string
	CreatedAt   pgtype.Timestamp
	Name        string
	Bio         string
	IsFollower  bool
	IsFollowing bool
}
