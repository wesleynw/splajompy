package utilities

import (
	"context"
	"encoding/json"
	"math"
	"net/http"

	"golang.org/x/mod/semver"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
)

type ContextKey string

const UserContextKey ContextKey = "user"

func MapUserToPublicUser(user queries.User) models.PublicUser {
	publicUser := models.PublicUser{
		UserID:     user.UserID,
		Username:   user.Username,
		Email:      user.Email,
		Name:       user.Name.String,
		CreatedAt:  user.CreatedAt.Time,
		IsVerified: false,
	}

	if user.UserDisplayProperties != nil {
		publicUser.DisplayProperties = models.PublicUserDisplayProperties{
			FontChoiceId: user.UserDisplayProperties.FontChoiceId,
		}
	}

	return publicUser
}

// MapPost is a utility function to convert from queries.Post to models.Post.
func MapPost(post queries.Post) models.Post {
	return models.Post{
		PostID:     post.PostID,
		UserID:     post.UserID,
		Text:       post.Text.String,
		CreatedAt:  post.CreatedAt.Time.UTC(),
		Facets:     post.Facets,
		Visibility: (*models.VisibilityTypeEnum)(&post.Visibilitytype),
	}
}

// MapNotification is a utility function to convert from queries.Notification to models.Notification.
func MapNotification(notification queries.Notification) models.Notification {
	var postId *int
	if notification.PostID != nil {
		postId = notification.PostID
	}
	var commentId *int
	if notification.CommentID != nil {
		commentId = notification.CommentID
	}

	return models.Notification{
		NotificationID:   notification.NotificationID,
		UserID:           notification.UserID,
		PostID:           postId,
		CommentID:        commentId,
		TargetUserId:     notification.TargetUserID,
		Message:          notification.Message,
		Link:             notification.Link.String,
		Viewed:           notification.Viewed,
		Facets:           notification.Facets,
		NotificationType: models.NotificationType(notification.NotificationType),
		CreatedAt:        notification.CreatedAt.Time.UTC(),
	}
}

// MapComment is a utility function to convert from the queries.Comment returned from the DB, to the usable models.DetailedComment type.
func MapComment(comment queries.Comment, user models.PublicUser, isLiked bool) models.DetailedComment {
	return models.DetailedComment{
		CommentID: comment.CommentID,
		PostID:    comment.PostID,
		UserID:    comment.UserID,
		Text:      comment.Text,
		Facets:    comment.Facets,
		CreatedAt: comment.CreatedAt.Time,
		User:      user,
		IsLiked:   isLiked,
	}
}

type ErrorResponse struct {
	Message string `json:"message"`
}

func HandleError(w http.ResponseWriter, statusCode int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	response := models.APIResponse{
		Success: false,
		Error:   message,
	}
	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

func HandleSuccess[T any](w http.ResponseWriter, data T) {
	w.Header().Set("Content-Type", "application/json")
	response := models.APIResponse{
		Success: true,
		Data:    data,
	}
	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

func HandleEmptySuccess(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	err := json.NewEncoder(w).Encode(map[string]bool{"success": true})
	if err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

const AppVersionKey ContextKey = "app_version"

// IsAppUpdatedToVersion returns true if the app version indicated by the current request is greater
// than or equal to the targetVersion. The target version should in in the semver format, e.g. "v1.8.0".
func IsAppUpdatedToVersion(ctx context.Context, targetVersion string) bool {
	versionAny := ctx.Value(AppVersionKey)
	version, ok := versionAny.(string)
	if !ok || version == "unknown" {
		// if no context key, assume it's a manual API request, we're okay with allowing this
		return true
	}

	return semver.Compare(version, targetVersion) >= 0
}

func SeededRandom(seed int) float64 {
	var x = math.Sin(float64(seed)) * 1000
	return x - math.Floor(x)
}
