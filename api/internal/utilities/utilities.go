package utilities

import (
	"encoding/json"
	"net/http"

	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/models"
)

func MapUserToPublicUser(user *db.User) *models.PublicUser {
	return &models.PublicUser{
		UserID:    user.UserID,
		Username:  user.Username,
		Email:     user.Email,
		Name:      user.Name,
		CreatedAt: user.CreatedAt,
	}
}

type ErrorResponse struct {
	Message string `json:"message"`
}

func RespondWithError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(ErrorResponse{
		Message: message,
	})
}
