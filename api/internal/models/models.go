package models

import (
	"github.com/jackc/pgx/v5/pgtype"
	db "splajompy.com/api/v2/internal/db/generated"
)

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

type DetailedPost struct {
	Post         db.Post           `json:"post"`
	User         db.GetUserByIdRow `json:"user"`
	IsLiked      bool              `json:"isLiked"`
	Images       []db.Image        `json:"images"`
	CommentCount int               `json:"commentCount"`
}

type DetailedComment struct {
	CommentID int32            `json:"commentId"`
	PostID    int32            `json:"postId"`
	UserID    int32            `json:"userId"`
	Text      string           `json:"text"`
	CreatedAt pgtype.Timestamp `json:"createdAt"`
	User      PublicUser       `json:"user"`
	IsLiked   bool             `json:"isLiked"`
}

type PublicUser = db.GetUserByIdentifierRow

type DetailedUser struct {
	UserID      int32            `json:"userId"`
	Email       string           `json:"email"`
	Username    string           `json:"username"`
	CreatedAt   pgtype.Timestamp `json:"createdAt"`
	Name        string           `json:"name"`
	Bio         string           `json:"bio"`
	IsFollower  bool             `json:"isFollower"`
	IsFollowing bool             `json:"isFollowing"`
}
