package models

import (
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"time"
)

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

type RelevantLike struct {
	Username string `json:"username"`
	UserID   int    `json:"userId"`
}

type Notification struct {
	NotificationID int       `json:"notificationId"`
	UserID         int       `json:"userId"`
	PostID         int       `json:"postId"`
	CommentID      int       `json:"commentId"`
	Message        string    `json:"message"`
	Link           string    `json:"link"`
	Viewed         bool      `json:"viewed"`
	Facets         db.Facets `json:"facets"`
	CreatedAt      time.Time `json:"createdAt"`
}

type Post struct {
	PostID    int32     `json:"postId"`
	UserID    int32     `json:"userId"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"createdAt"`
	Facets    db.Facets `json:"facets"`
}

type DetailedPost struct {
	Post          Post            `json:"post"`
	User          PublicUser      `json:"user"`
	IsLiked       bool            `json:"isLiked"`
	Images        []queries.Image `json:"images"`
	CommentCount  int             `json:"commentCount"`
	RelevantLikes []RelevantLike  `json:"relevantLikes"`
	HasOtherLikes bool            `json:"hasOtherLikes"`
}

type DetailedComment struct {
	CommentID int        `json:"commentId"`
	PostID    int        `json:"postId"`
	UserID    int        `json:"userId"`
	Text      string     `json:"text"`
	Facets    db.Facets  `json:"facets"`
	CreatedAt time.Time  `json:"createdAt"`
	User      PublicUser `json:"user"`
	IsLiked   bool       `json:"isLiked"`
}

type DetailedNotification struct {
	Notification
	Post      *Post            `json:"post"`
	Comment   *queries.Comment `json:"comment"`
	ImageBlob *string          `json:"imageBlob"`
}

// PublicUser Related to queries.GetUserByIdentifierRow
type PublicUser struct {
	UserID    int       `json:"userId"`
	Email     string    `json:"email"`
	Username  string    `json:"username"`
	CreatedAt time.Time `json:"createdAt"`
	Name      string    `json:"name"`
}

type DetailedUser struct {
	UserID      int       `json:"userId"`
	Email       string    `json:"email"`
	Username    string    `json:"username"`
	CreatedAt   time.Time `json:"createdAt"`
	Name        string    `json:"name"`
	Bio         string    `json:"bio"`
	IsFollower  bool      `json:"isFollower"`
	IsFollowing bool      `json:"isFollowing"`
	IsBlocking  bool      `json:"isBlocking"`
}
