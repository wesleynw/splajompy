package models

import (
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db/queries"
)

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

type RelevantLike struct {
	Username string `json:"username"`
	UserID   int32  `json:"userId"`
}

type DetailedPost struct {
	Post          queries.Post    `json:"post"`
	User          PublicUser      `json:"user"`
	IsLiked       bool            `json:"isLiked"`
	Images        []queries.Image `json:"images"`
	CommentCount  int             `json:"commentCount"`
	RelevantLikes []RelevantLike  `json:"relevantLikes"`
	HasOtherLikes bool            `json:"hasOtherLikes"`
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

type DetailedNotification struct {
	queries.Notification
	Post    *queries.Post    `json:"post"`
	Comment *queries.Comment `json:"comment"`
}

type PublicUser = queries.GetUserByIdentifierRow

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
