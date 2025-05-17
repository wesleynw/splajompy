package utilities

import (
	"encoding/json"
	"net/http"
	"splajompy.com/api/v2/internal/db/queries"

	"splajompy.com/api/v2/internal/models"
)

func MapUserToPublicUser(user queries.User) models.PublicUser {
	return models.PublicUser{
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
