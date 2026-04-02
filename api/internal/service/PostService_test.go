package service_test

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/service"
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
func (f *fakeBucketRepository) PublishStagedImages(_ context.Context, _ int, _ string, _ int, imageKeymap map[int]models.ImageData) (map[int]string, error) {
	keys := make(map[int]string, len(imageKeymap))
	for i, data := range imageKeymap {
		keys[i] = data.S3Key
	}
	return keys, nil
}

type postServiceTestEnv struct {
	svc            *service.PostService
	userRepository repositories.UserRepository
}

func setupPostTest(t *testing.T) postServiceTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	likeRepository := repositories.NewDBLikeRepository(testDb.Queries)
	notificationRepository := repositories.NewDBNotificationRepository(testDb.Queries)
	bucketRepository := &fakeBucketRepository{}

	svc := service.NewPostService(postRepository, userRepository, likeRepository, notificationRepository, bucketRepository, nil)

	_ = os.Setenv("ENVIRONMENT", "test")

	return postServiceTestEnv{
		svc:            svc,
		userRepository: userRepository,
	}
}

func TestGetPostById(t *testing.T) {
	env := setupPostTest(t)

	user := testutil.CreateTestUser(t, env.userRepository, "user1")

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
	env := setupPostTest(t)

	user := testutil.CreateTestUser(t, env.userRepository, "user0")

	post, err := env.svc.NewPost(t.Context(), user, "post 0", nil, nil, nil)
	require.NoError(t, err)

	err = env.svc.DeletePost(t.Context(), user, post.PostID)
	assert.NoError(t, err)

	_, err = env.svc.GetPostById(t.Context(), user.UserID, post.PostID)
	assert.Error(t, err)
}

func TestCreatePostWithImages_ReturnsImages(t *testing.T) {
	env := setupPostTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	images := map[int]models.ImageData{
		1: {S3Key: "images/photo1.jpg", Width: 1920, Height: 1080},
		2: {S3Key: "images/photo2.jpg", Width: 800, Height: 600},
		3: {S3Key: "images/photo3.jpg", Width: 400, Height: 400},
	}

	post_initial, err := env.svc.NewPost(t.Context(), user0, "test post with images", images, nil, nil)
	require.NoError(t, err)

	post, err := env.svc.GetPostById(t.Context(), user0.UserID, post_initial.PostID)
	require.NoError(t, err)
	assert.NotNil(t, post)
	assert.NotEmpty(t, post.Images)
	assert.Len(t, post.Images, len(images))
}

func TestGetPosts_DoesNotReturnPrivatePosts(t *testing.T) {
	env := setupPostTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), user0, "test post please ignore", nil, nil, new(int(models.VisibilityCloseFriends)))
	assert.NoError(t, err)

	// user1 should not be able to see the private post
	returned_post, err := env.svc.GetPostById(t.Context(), user1.UserID, post.PostID)
	assert.Error(t, err)
	assert.Nil(t, returned_post)

	all_posts, err := env.svc.GetPosts(t.Context(), user1, service.FeedTypeAll, nil, 10, nil)
	require.NoError(t, err)
	assert.Len(t, all_posts, 0)

	mutual_posts, err := env.svc.GetPosts(t.Context(), user1, service.FeedTypeMutual, nil, 10, nil)
	require.NoError(t, err)
	assert.Len(t, mutual_posts, 0)

	following_posts, err := env.svc.GetPosts(t.Context(), user1, service.FeedTypeFollowing, nil, 10, nil)
	require.NoError(t, err)
	assert.Len(t, following_posts, 0)

	profile_posts, err := env.svc.GetPosts(t.Context(), user1, service.FeedTypeProfile, &user0.UserID, 10, nil)
	require.NoError(t, err)
	assert.Len(t, profile_posts, 0)
}

func TestGetPostById_HiddenWhenPosterBlockedViewer(t *testing.T) {
	env := setupPostTest(t)

	poster := testutil.CreateTestUser(t, env.userRepository, "user0")
	viewer := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), poster, "post0", nil, nil, nil)
	require.NoError(t, err)

	returned_post, err := env.svc.GetPostById(t.Context(), viewer.UserID, post.PostID)
	assert.NoError(t, err)
	assert.Equal(t, post.PostID, returned_post.Post.PostID)

	err = env.userRepository.BlockUser(t.Context(), poster.UserID, viewer.UserID)
	assert.NoError(t, err)

	returned_post, err = env.svc.GetPostById(t.Context(), viewer.UserID, post.PostID)
	assert.Error(t, err)
	assert.Nil(t, returned_post)
}

func TestGetPosts_HiddenWhenPosterBlockedViewer(t *testing.T) {
	env := setupPostTest(t)

	poster := testutil.CreateTestUser(t, env.userRepository, "user0")
	viewer := testutil.CreateTestUser(t, env.userRepository, "user1")

	_, err := env.svc.NewPost(t.Context(), poster, "post0", nil, nil, nil)
	require.NoError(t, err)

	err = env.userRepository.BlockUser(t.Context(), poster.UserID, viewer.UserID)
	assert.NoError(t, err)

	posts, err := env.svc.GetPosts(t.Context(), viewer, service.FeedTypeAll, nil, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)

	posts, err = env.svc.GetPosts(t.Context(), viewer, service.FeedTypeFollowing, nil, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)

	posts, err = env.svc.GetPosts(t.Context(), viewer, service.FeedTypeMutual, nil, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)

	posts, err = env.svc.GetPosts(t.Context(), viewer, service.FeedTypeProfile, &poster.UserID, 10, nil)
	assert.NoError(t, err)
	assert.Len(t, posts, 0)
}

// TestGetPosts_ProfilePinnedPostDoesNotReduceSubsequentPageSize documents a bug where
// fetching a profile page returns limit-1 posts instead of limit when the pinned post
// happens to fall within that page's DB results. The frontend interprets a result shorter
// than the requested limit as the end of the feed, causing posts beyond that page to
// never be fetched.
func TestGetPosts_ProfilePinnedPostDoesNotReduceSubsequentPageSize(t *testing.T) {
	env := setupPostTest(t)

	// enables pinned-post logic.
	ctx := context.WithValue(t.Context(), middleware.AppVersionKey, "v1.4.0")

	user := testutil.CreateTestUser(t, env.userRepository, "user1")

	const limit = 3

	created := make([]*models.Post, 3*limit)
	for i := range created {
		p, err := env.svc.NewPost(ctx, user, fmt.Sprintf("post %d", i), nil, nil, nil)
		require.NoError(t, err)
		created[i] = p
	}

	err := env.svc.PinPost(ctx, user, created[0].PostID)
	require.NoError(t, err)

	page1, err := env.svc.GetPosts(ctx, user, service.FeedTypeProfile, &user.UserID, limit, nil)
	require.NoError(t, err)
	require.Len(t, page1, limit+1) // pinned post returned in first page

	cursor := page1[len(page1)-1].Post.CreatedAt

	page2, err := env.svc.GetPosts(ctx, user, service.FeedTypeProfile, &user.UserID, limit, &cursor)
	require.NoError(t, err)
	assert.Len(t, page2, limit)
	for _, p := range page2 {
		assert.NotEqual(t, created[0].PostID, p.Post.PostID, "pinned post should not appear again in subsequent pages")
	}
}

func TestGetPost_DoesNotReturnRelevantLikesForBlockingUser(t *testing.T) {
	env := setupPostTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), user0, "test post", nil, nil, nil)
	require.NoError(t, err)

	env.svc.AddLikeToPost(t.Context(), user1, post.PostID)

	full_post, err := env.svc.GetPostById(t.Context(), user0.UserID, post.PostID)
	require.NoError(t, err)

	assert.NotEmpty(t, full_post.RelevantLikes)
	assert.Len(t, full_post.RelevantLikes, 1)
	assert.Equal(t, "user1", full_post.RelevantLikes[0].Username)

	err = env.userRepository.BlockUser(t.Context(), user0.UserID, user1.UserID)
	require.NoError(t, err)

	full_post, err = env.svc.GetPostById(t.Context(), user0.UserID, post.PostID)
	require.NoError(t, err)

	assert.Empty(t, full_post.RelevantLikes)
}

func TestGetPost_DoesNotReturnRelevantLikesForBlockedUser(t *testing.T) {
	env := setupPostTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.svc.NewPost(t.Context(), user0, "test post", nil, nil, nil)
	require.NoError(t, err)

	env.svc.AddLikeToPost(t.Context(), user1, post.PostID)

	full_post, err := env.svc.GetPostById(t.Context(), user0.UserID, post.PostID)
	require.NoError(t, err)

	assert.NotEmpty(t, full_post.RelevantLikes)
	assert.Len(t, full_post.RelevantLikes, 1)
	assert.Equal(t, "user1", full_post.RelevantLikes[0].Username)

	err = env.userRepository.BlockUser(t.Context(), user1.UserID, user0.UserID)
	require.NoError(t, err)

	full_post, err = env.svc.GetPostById(t.Context(), user0.UserID, post.PostID)
	require.NoError(t, err)

	assert.Empty(t, full_post.RelevantLikes)
}

func TestGetPost_DoesNotReturnRelevantLikesCurrentUser(t *testing.T) {
	env := setupPostTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	post, err := env.svc.NewPost(t.Context(), user0, "test post", nil, nil, nil)
	require.NoError(t, err)

	env.svc.AddLikeToPost(t.Context(), user0, post.PostID)

	full_post, err := env.svc.GetPostById(t.Context(), user0.UserID, post.PostID)
	require.NoError(t, err)
	assert.Empty(t, full_post.RelevantLikes)
}
