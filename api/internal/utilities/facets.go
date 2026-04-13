package utilities

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
)

type userReader interface {
	GetUserByUsername(ctx context.Context, username string) (models.PublicUser, error)
}

func GenerateFacets(ctx context.Context, userRepository userReader, text string) (db.Facets, error) {
	matches := MentionRegex.FindAllStringSubmatchIndex(text, -1)

	var facets db.Facets

	for _, match := range matches {
		usernameStart, usernameEnd := match[2], match[3]
		username := text[usernameStart:usernameEnd]
		user, err := userRepository.GetUserByUsername(ctx, username)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return nil, err
		}
		facets = append(facets, db.Facet{
			Type:       "mention",
			UserId:     user.UserID,
			IndexStart: usernameStart - 1,
			IndexEnd:   usernameEnd,
		})
	}

	return facets, nil
}
