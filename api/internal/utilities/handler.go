package utilities

import (
	"errors"
	"net/http"
	"strconv"

	"splajompy.com/api/v2/internal/models"
)

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
