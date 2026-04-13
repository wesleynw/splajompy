package utilities

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"splajompy.com/api/v2/internal/models"
)

var ErrUnauthorized = errors.New("unauthorized")

func GetAuthenticatedUser(r *http.Request) *models.PublicUser {
	return new(r.Context().Value(UserContextKey).(models.PublicUser))
}

func GetIntPathParam(r *http.Request, paramName string) (int, error) {
	paramString := r.PathValue(paramName)
	if paramString == "" {
		return 0, errors.New("missing url parameter")
	}
	param, err := strconv.Atoi(paramString)
	if err != nil {
		return 0, errors.New("cannot parse url parameter")
	}

	return param, nil
}

func ParseTimeBasedPagination(r *http.Request) (int, *time.Time, error) {
	limit := 10
	if l, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && l > 0 {
		limit = l
	}

	var beforeTimestamp *time.Time
	beforeStr := r.URL.Query().Get("before")
	if beforeStr != "" {
		timestamp, err := time.Parse(time.RFC3339, beforeStr)
		if err != nil {
			return 0, nil, errors.New("invalid timestamp format, expected RFC3339")
		}
		beforeTimestamp = &timestamp
	}

	return limit, beforeTimestamp, nil
}
