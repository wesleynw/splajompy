package models

import (
	"time"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type NotificationType string

const (
	NotificationTypeMention      NotificationType = "mention"
	NotificationTypeLike         NotificationType = "like"
	NotificationTypeComment      NotificationType = "comment"
	NotificationTypeAnnouncement NotificationType = "announcement"
	NotificationTypeFollowers    NotificationType = "followers"
	NotificationTypePoll         NotificationType = "poll"
)

func (nt NotificationType) String() string {
	return string(nt)
}

func (nt NotificationType) IsValid() bool {
	switch nt {
	case NotificationTypeMention, NotificationTypeLike, NotificationTypeComment, NotificationTypeAnnouncement, NotificationTypeFollowers, NotificationTypePoll:
		return true
	default:
		return false
	}
}

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
	NotificationID   int              `json:"notificationId"`
	UserID           int              `json:"userId"`
	PostID           *int             `json:"postId"`
	CommentID        *int             `json:"commentId"`
	Message          string           `json:"message"`
	Link             string           `json:"link"`
	Viewed           bool             `json:"viewed"`
	Facets           db.Facets        `json:"facets"`
	NotificationType NotificationType `json:"notificationType"`
	CreatedAt        time.Time        `json:"createdAt"`
}

type Post struct {
	PostID     int            `json:"postId"`
	UserID     int32          `json:"userId"`
	Text       string         `json:"text"`
	CreatedAt  time.Time      `json:"createdAt"`
	Facets     db.Facets      `json:"facets"`
	Attributes *db.Attributes `json:"attributes"`
}

type DetailedPost struct {
	Post          Post            `json:"post"`
	User          PublicUser      `json:"user"`
	IsLiked       bool            `json:"isLiked"`
	Images        []queries.Image `json:"images"`
	CommentCount  int             `json:"commentCount"`
	RelevantLikes []RelevantLike  `json:"relevantLikes"`
	HasOtherLikes bool            `json:"hasOtherLikes"`
	Poll          *DetailedPoll   `json:"poll"`
}

type DetailedPollOption struct {
	Title     string `json:"title"`
	VoteTotal int    `json:"voteTotal"`
}

type DetailedPoll struct {
	Title           string               `json:"title"`
	VoteTotal       int                  `json:"voteTotal"`
	CurrentUserVote *int                 `json:"currentUserVote"`
	Options         []DetailedPollOption `json:"options"`
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
	Post        *Post            `json:"post"`
	Comment     *queries.Comment `json:"comment"`
	ImageBlob   *string          `json:"imageBlob"`
	ImageWidth  *int32           `json:"imageWidth"`
	ImageHeight *int32           `json:"imageHeight"`
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
	Mutuals     []string  `json:"mutuals"`
}

type ImageData struct {
	S3Key  string `json:"s3Key"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}
