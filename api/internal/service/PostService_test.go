package service

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/testutil"
)

type fakeBucketRepository struct{}

func (f *fakeBucketRepository) CopyObject(_ context.Context, _, _ string) error   { return nil }
func (f *fakeBucketRepository) DeleteObject(_ context.Context, _ string) error    { return nil }
func (f *fakeBucketRepository) DeleteObjects(_ context.Context, _ []string) error { return nil }
func (f *fakeBucketRepository) GetPresignedPutObject(_ context.Context, _ int, _, _ *string) (string, string, error) {
	return "", "", nil
}
func (f *fakeBucketRepository) GetPresignedGetObject(_ context.Context, key string) (*string, error) {
	return &key, nil
}

type postServiceTestEnv struct {
	svc *PostService
}

func setupTest(t *testing.T) postServiceTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	likeRepository := repositories.NewDBLikeRepository(testDb.Queries)
	notificationRepository := repositories.NewDBNotificationRepository(testDb.Queries)
	bucketRepository := &fakeBucketRepository{}

	svc := NewPostService(postRepository, userRepository, likeRepository, notificationRepository, bucketRepository, nil)

	_ = os.Setenv("ENVIRONMENT", "test")

	return postServiceTestEnv{
		svc: svc,
	}
}

func TestGetPostById(t *testing.T) {
	env := setupTest(t)

	user := testutil.CreateTestUser(t, env.svc.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), user, "post 1", nil, nil, nil)
	require.NoError(t, err)

	post_returned, err := env.svc.GetPostById(t.Context(), user.UserID, post.PostID)
	assert.NoError(t, err)
	assert.NotNil(t, post_returned)

	assert.Equal(t, post.PostID, post_returned.Post.PostID)
	assert.Equal(t, "post 1", post_returned.Post.Text)
	assert.Equal(t, user.UserID, post_returned.User.UserID)
	assert.Equal(t, user.Username, post_returned.User.Username)
}

func TestDeletePost(t *testing.T) {
	env := setupTest(t)

	user := testutil.CreateTestUser(t, env.svc.userRepository, "user0")

	post, err := env.svc.NewPost(t.Context(), user, "post 0", nil, nil, nil)
	require.NoError(t, err)

	err = env.svc.DeletePost(t.Context(), user, post.PostID)
	assert.NoError(t, err)

	_, err = env.svc.GetPostById(t.Context(), user.UserID, post.PostID)
	assert.Error(t, err)
}

func TestGetPosts_DoesNotReturnPrivatePosts(t *testing.T) {
	env := setupTest(t)

	user0 := testutil.CreateTestUser(t, env.svc.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.svc.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), user0, "test post please ignore", nil, nil, new(int(models.VisibilityCloseFriends)))
	assert.NoError(t, err)

	// user1 should not be able to see the private post
	returned_post, err := env.svc.GetPostById(t.Context(), user1.UserID, post.PostID)
	assert.Error(t, err)
	assert.Nil(t, returned_post)

	all_posts, err := env.svc.GetPosts(t.Context(), user1, FeedTypeAll, nil, 10, nil)
	require.NoError(t, err)
	assert.Len(t, all_posts, 0)

	mutual_posts, err := env.svc.GetPosts(t.Context(), user1, FeedTypeMutual, nil, 10, nil)
	require.NoError(t, err)
	assert.Len(t, mutual_posts, 0)

	following_posts, err := env.svc.GetPosts(t.Context(), user1, FeedTypeFollowing, nil, 10, nil)
	require.NoError(t, err)
	assert.Len(t, following_posts, 0)

	profile_posts, err := env.svc.GetPosts(t.Context(), user1, FeedTypeProfile, &user0.UserID, 10, nil)
	require.NoError(t, err)
	assert.Len(t, profile_posts, 0)
}

func TestGetPostById_HiddenWhenPosterBlockedViewer(t *testing.T) {
	env := setupTest(t)

	poster := testutil.CreateTestUser(t, env.svc.userRepository, "user0")
	viewer := testutil.CreateTestUser(t, env.svc.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), poster, "post0", nil, nil, nil)
	require.NoError(t, err)

	returned_post, err := env.svc.GetPostById(t.Context(), viewer.UserID, post.PostID)
	assert.NoError(t, err)
	assert.Equal(t, post.PostID, returned_post.Post.PostID)

	err = env.svc.userRepository.BlockUser(t.Context(), poster.UserID, viewer.UserID)
	assert.NoError(t, err)

	returned_post, err = env.svc.GetPostById(t.Context(), viewer.UserID, post.PostID)
	assert.Error(t, err)
	assert.Nil(t, returned_post)
}

func TestGetPosts_HiddenWhenPosterBlockedViewer(t *testing.T) {
	env := setupTest(t)

	poster := testutil.CreateTestUser(t, env.svc.userRepository, "user0")
	viewer := testutil.CreateTestUser(t, env.svc.userRepository, "user1")

	_, err := env.svc.NewPost(t.Context(), poster, "post0", nil, nil, nil)
	require.NoError(t, err)

	err = env.svc.userRepository.BlockUser(t.Context(), poster.UserID, viewer.UserID)
	assert.NoError(t, err)

	posts, err := env.svc.GetPosts(t.Context(), viewer, FeedTypeAll, nil, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)

	posts, err = env.svc.GetPosts(t.Context(), viewer, FeedTypeFollowing, nil, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)

	posts, err = env.svc.GetPosts(t.Context(), viewer, FeedTypeMutual, nil, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)

	posts, err = env.svc.GetPosts(t.Context(), viewer, FeedTypeProfile, &poster.UserID, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)
}

// TestGetPosts_ProfilePinnedPostDoesNotReduceSubsequentPageSize documents a bug where
// fetching a profile page returns limit-1 posts instead of limit when the pinned post
// happens to fall within that page's DB results. The frontend interprets a result shorter
// than the requested limit as the end of the feed, causing posts beyond that page to
// never be fetched.
func TestGetPosts_ProfilePinnedPostDoesNotReduceSubsequentPageSize(t *testing.T) {
	env := setupTest(t)

	// enables pinned-post logic.
	ctx := context.WithValue(t.Context(), middleware.AppVersionKey, "v1.4.0")

	user := testutil.CreateTestUser(t, env.svc.userRepository, "user1")

	const limit = 3

	created := make([]*models.Post, 2*limit)
	for i := range created {
		p, err := env.svc.NewPost(ctx, user, fmt.Sprintf("post %d", i), nil, nil, nil)
		require.NoError(t, err)
		created[i] = p
		time.Sleep(time.Millisecond)
	}

	err := env.svc.PinPost(ctx, user, created[0].PostID)
	require.NoError(t, err)

	page1, err := env.svc.GetPosts(ctx, user, FeedTypeProfile, &user.UserID, limit, nil)
	require.NoError(t, err)
	require.Len(t, page1, limit+1) // pinned post returned in first page

	cursor := page1[len(page1)-1].Post.CreatedAt

	page2, err := env.svc.GetPosts(ctx, user, FeedTypeProfile, &user.UserID, limit, &cursor)
	require.NoError(t, err)
	assert.Len(t, page2, limit)
	for _, p := range page2 {
		assert.NotEqual(t, created[0].PostID, p.Post.PostID, "pinned post should not appear again in subsequent pages")
	}
}
