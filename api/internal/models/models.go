package models

import (
	"encoding/json"
	"time"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type UserDisplayProperties struct {
	FontChoiceId     *int       `json:"fontChoiceId"`
	LatestAppVersion *string    `json:"latestAppVersion"`
	LastLoginDate    *time.Time `json:"lastLoginDate"`
}

// PublicUserDisplayProperties contains only user-facing display properties.
type PublicUserDisplayProperties struct {
	FontChoiceId *int `json:"fontChoiceId"`
}

type NotificationType string

const (
	NotificationTypeMention      NotificationType = "mention"
	NotificationTypeLike         NotificationType = "like"
	NotificationTypeComment      NotificationType = "comment"
	NotificationTypeAnnouncement NotificationType = "announcement"
	NotificationTypeFollowers    NotificationType = "followers"
	NotificationTypePoll         NotificationType = "poll"
)

type APIResponse struct {
	Success bool   `json:"success"`
	Data    any    `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

type RelevantLike struct {
	Username string `json:"username"`
	UserID   int    `json:"userId"`
}

type Notification struct {
	NotificationID        int              `json:"notificationId"`
	UserID                int              `json:"userId"`
	PostID                *int             `json:"postId"`
	CommentID             *int             `json:"commentId"`
	TargetUserId          *int             `json:"targetUserId"`
	Message               string           `json:"message"`
	Link                  string           `json:"link"`
	Viewed                bool             `json:"viewed"`
	Facets                db.Facets        `json:"facets"`
	NotificationType      NotificationType `json:"notificationType"`
	CreatedAt             time.Time        `json:"createdAt"`
	HasNotificationActors bool             `json:"hasNotificationActors"`
}

type Post struct {
	PostID     int                 `json:"postId"`
	UserID     int                 `json:"userId"`
	Text       string              `json:"text"`
	CreatedAt  time.Time           `json:"createdAt"`
	Facets     db.Facets           `json:"facets"`
	Attributes *db.Attributes      `json:"attributes"`
	Visibility *VisibilityTypeEnum `json:"visibility"`
}

type DetailedPost struct {
	Post          Post            `json:"post"`
	User          PublicUser      `json:"user"`
	IsLiked       bool            `json:"isLiked"`
	Images        []DetailedImage `json:"images"`
	CommentCount  int             `json:"commentCount"`
	RelevantLikes []RelevantLike  `json:"relevantLikes"`
	HasOtherLikes bool            `json:"hasOtherLikes"`
	Poll          *DetailedPoll   `json:"poll"`
	IsPinned      bool            `json:"isPinned"`
}

type DetailedImage struct {
	ImageID      int    `json:"imageId"`
	PostId       int    `json:"postId"`
	Height       int    `json:"height"`
	Width        int    `json:"width"`
	ImageBlobUrl string `json:"imageBlobUrl"`
	DisplayOrder int    `json:"displayOrder"`
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
	CommentID int             `json:"commentId"`
	PostID    int             `json:"postId"`
	UserID    int             `json:"userId"`
	Text      string          `json:"text"`
	Facets    db.Facets       `json:"facets"`
	CreatedAt time.Time       `json:"createdAt"`
	User      PublicUser      `json:"user"`
	IsLiked   bool            `json:"isLiked"`
	Images    []DetailedImage `json:"images"`
}

type DetailedNotification struct {
	Notification
	Post               *Post            `json:"post"`
	Comment            *queries.Comment `json:"comment"`
	ImageBlob          *string          `json:"imageBlob"`
	ImageWidth         *int             `json:"imageWidth"`
	ImageHeight        *int             `json:"imageHeight"`
	TargetUserUsername *string          `json:"targetUserUsername"`
}

type FullUser struct {
	UserID            int                         `json:"userId"`
	Email             string                      `json:"email"`
	Username          string                      `json:"username"`
	CreatedAt         time.Time                   `json:"createdAt"`
	Name              string                      `json:"name"`
	DisplayProperties PublicUserDisplayProperties `json:"displayProperties"`
}

type PublicUser struct {
	UserID            int                         `json:"userId"`
	Email             string                      `json:"email"`
	Username          string                      `json:"username"`
	CreatedAt         time.Time                   `json:"createdAt"`
	Name              string                      `json:"name"`
	IsVerified        bool                        `json:"isVerified"`
	DisplayProperties PublicUserDisplayProperties `json:"displayProperties"`
	IsFriend          *bool                       `json:"isFriend,omitempty"`
}

func (u PublicUser) MarshalJSON() ([]byte, error) {
	type Alias PublicUser
	return json.Marshal(Alias{
		UserID:            u.UserID,
		Email:             "",
		Username:          u.Username,
		CreatedAt:         u.CreatedAt,
		Name:              u.Name,
		IsVerified:        u.IsVerified,
		DisplayProperties: u.DisplayProperties,
		IsFriend:          u.IsFriend,
	})
}

type DetailedUser struct {
	UserID            int                         `json:"userId"`
	Email             string                      `json:"email"`
	Username          string                      `json:"username"`
	CreatedAt         time.Time                   `json:"createdAt"`
	Name              string                      `json:"name"`
	Bio               string                      `json:"bio"`
	IsFollower        bool                        `json:"isFollower"`
	IsFollowing       bool                        `json:"isFollowing"`
	IsBlocking        bool                        `json:"isBlocking"`
	IsMuting          bool                        `json:"isMuting"`
	IsFriend          bool                        `json:"isFriend"`
	Mutuals           []string                    `json:"mutuals"`
	MutualCount       int                         `json:"mutualCount"`
	IsVerified        bool                        `json:"isVerified"`
	DisplayProperties PublicUserDisplayProperties `json:"displayProperties"`
}

func (u DetailedUser) MarshalJSON() ([]byte, error) {
	type Alias DetailedUser
	return json.Marshal(Alias{
		UserID:            u.UserID,
		Email:             "",
		Username:          u.Username,
		CreatedAt:         u.CreatedAt,
		Name:              u.Name,
		Bio:               u.Bio,
		IsFollower:        u.IsFollower,
		IsFollowing:       u.IsFollowing,
		IsBlocking:        u.IsBlocking,
		IsMuting:          u.IsMuting,
		IsFriend:          u.IsFriend,
		Mutuals:           u.Mutuals,
		MutualCount:       u.MutualCount,
		IsVerified:        u.IsVerified,
		DisplayProperties: u.DisplayProperties,
	})
}

type PaginatedUserList struct {
	Users      []DetailedUser `json:"users"`
	NextCursor *time.Time     `json:"nextCursor,omitempty"`
}

type ImageData struct {
	S3Key  string `json:"s3Key"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

type AppStats struct {
	TotalPosts         int64 `json:"totalPosts"`
	TotalComments      int64 `json:"totalComments"`
	TotalLikes         int64 `json:"totalLikes"`
	TotalFollows       int64 `json:"totalFollows"`
	TotalUsers         int64 `json:"totalUsers"`
	TotalNotifications int64 `json:"totalNotifications"`
}

type VisibilityTypeEnum int

const (
	VisibilityPublic       VisibilityTypeEnum = 0
	VisibilityCloseFriends VisibilityTypeEnum = 1
)

type Device struct {
	UserID            int    `json:"userId"`
	Token             string `json:"token"`
	IsEnabledMentions bool   `json:"isEnabledMentions"`
	IsEnabledComments bool   `json:"isEnabledComments"`
	IsEnabledFollows  bool   `json:"isEnabledFollows"`
}
