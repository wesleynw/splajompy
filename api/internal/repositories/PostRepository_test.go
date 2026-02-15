//go:build integration
// +build integration

package repositories_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/testutil"
)

func TestInsertAndGetPost(t *testing.T) {
	tdb := testutil.StartPostgres(t)
	ctx := context.Background()

	userRepo := repositories.NewDBUserRepository(tdb.Queries)
	postRepo := repositories.NewDBPostRepository(tdb.Queries)

	user, err := userRepo.CreateUser(ctx, "testuser", "test@example.com", "password123", "REF001")
	require.NoError(t, err)

	visibility := models.VisibilityTypeEnum(0)
	post, err := postRepo.InsertPost(ctx, user.UserID, "hello world", db.Facets{}, nil, &visibility)
	require.NoError(t, err)
	assert.Equal(t, "hello world", post.Text)
	assert.Equal(t, user.UserID, post.UserID)

	fetched, err := postRepo.GetPostById(ctx, post.PostID, user.UserID)
	require.NoError(t, err)
	assert.Equal(t, post.PostID, fetched.PostID)
	assert.Equal(t, "hello world", fetched.Text)
}

func TestDeletePost(t *testing.T) {
	tdb := testutil.StartPostgres(t)
	ctx := context.Background()

	userRepo := repositories.NewDBUserRepository(tdb.Queries)
	postRepo := repositories.NewDBPostRepository(tdb.Queries)

	user, err := userRepo.CreateUser(ctx, "testuser", "test@example.com", "password123", "REF001")
	require.NoError(t, err)

	visibility := models.VisibilityTypeEnum(0)
	post, err := postRepo.InsertPost(ctx, user.UserID, "to be deleted", db.Facets{}, nil, &visibility)
	require.NoError(t, err)

	err = postRepo.DeletePost(ctx, post.PostID)
	require.NoError(t, err)

	_, err = postRepo.GetPostById(ctx, post.PostID, user.UserID)
	assert.Error(t, err)
}

func TestInsertImageForPost(t *testing.T) {
	tdb := testutil.StartPostgres(t)
	ctx := context.Background()

	userRepo := repositories.NewDBUserRepository(tdb.Queries)
	postRepo := repositories.NewDBPostRepository(tdb.Queries)

	user, err := userRepo.CreateUser(ctx, "testuser", "test@example.com", "password123", "REF001")
	require.NoError(t, err)

	visibility := models.VisibilityTypeEnum(0)
	post, err := postRepo.InsertPost(ctx, user.UserID, "post with image", db.Facets{}, nil, &visibility)
	require.NoError(t, err)

	img, err := postRepo.InsertImage(ctx, post.PostID, 100, 200, "https://example.com/img.png", 0)
	require.NoError(t, err)
	assert.Equal(t, 100, img.Height)
	assert.Equal(t, 200, img.Width)

	images, err := postRepo.GetImagesForPost(ctx, post.PostID)
	require.NoError(t, err)
	assert.Len(t, images, 1)
}

func TestGetAllPostIdsCursor_ExcludesBlockedUser(t *testing.T) {
	tdb := testutil.StartPostgres(t)
	ctx := context.Background()

	userRepo := repositories.NewDBUserRepository(tdb.Queries)
	postRepo := repositories.NewDBPostRepository(tdb.Queries)

	poster, err := userRepo.CreateUser(ctx, "poster", "poster@example.com", "password123", "REF001")
	require.NoError(t, err)

	viewer, err := userRepo.CreateUser(ctx, "viewer", "viewer@example.com", "password123", "REF002")
	require.NoError(t, err)

	visibility := models.VisibilityTypeEnum(0)
	_, err = postRepo.InsertPost(ctx, poster.UserID, "visible post", db.Facets{}, nil, &visibility)
	require.NoError(t, err)

	ids, err := postRepo.GetAllPostIdsCursor(ctx, 10, nil, viewer.UserID)
	require.NoError(t, err)
	assert.Len(t, ids, 1)

	err = userRepo.BlockUser(ctx, viewer.UserID, poster.UserID)
	require.NoError(t, err)

	ids, err = postRepo.GetAllPostIdsCursor(ctx, 10, nil, viewer.UserID)
	require.NoError(t, err)
	assert.Empty(t, ids)
}
