package utilities

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"net/http"
	"regexp"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/repositories"

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

func GenerateFacets(ctx context.Context, userRepository repositories.UserRepository, text string) (db.Facets, error) {
	re := regexp.MustCompile(`@(\w+)`)
	matches := re.FindAllStringSubmatchIndex(text, -1)

	var facets db.Facets

	for _, match := range matches {
		start, end := match[0], match[1]
		username := text[start+1 : end]
		user, err := userRepository.GetUserByUsername(ctx, username)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return nil, err
		}
		facets = append(facets, db.Facet{
			Type:       "mention",
			UserId:     int(user.UserID),
			IndexStart: start,
			IndexEnd:   end,
		})
	}

	return facets, nil
}
