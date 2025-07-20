package utilities

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
)

func MapUserToPublicUser(user queries.User) models.PublicUser {
	return models.PublicUser{
		UserID:    int(user.UserID),
		Username:  user.Username,
		Email:     user.Email,
		Name:      user.Name.String,
		CreatedAt: user.CreatedAt.Time,
	}
}

// MapPost is a utility function to convert from queries.Post to models.Post.
func MapPost(post queries.Post) models.Post {
	return models.Post{
		PostID:    int(post.PostID),
		UserID:    post.UserID,
		Text:      post.Text.String,
		CreatedAt: post.CreatedAt.Time.UTC(),
		Facets:    post.Facets,
	}
}

// MapNotification is a utility function to convert from queries.Notification to models.Notification.
func MapNotification(notification queries.Notification) models.Notification {
	var postId *int
	if notification.PostID.Valid {
		id := int(notification.PostID.Int32)
		postId = &id
	}

	var commentId *int
	if notification.CommentID.Valid {
		id := int(notification.CommentID.Int32)
		commentId = &id
	}

	return models.Notification{
		NotificationID:   int(notification.NotificationID),
		UserID:           int(notification.UserID),
		PostID:           postId,
		CommentID:        commentId,
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
		CommentID: int(comment.CommentID),
		PostID:    int(comment.PostID),
		UserID:    int(comment.UserID),
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
