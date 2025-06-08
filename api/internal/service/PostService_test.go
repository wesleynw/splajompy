package service

import (
	"context"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"os"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/repositories/fakes"
	"testing"
)

func setupTest(t *testing.T) (*PostService, *fakes.FakePostRepository, *fakes.FakeUserRepository, *fakes.FakeLikeRepository, *fakes.FakeNotificationRepository, *fakes.FakeBucketRepository, models.PublicUser) {
	postRepo := fakes.NewFakePostRepository()
	userRepo := fakes.NewFakeUserRepository()
	likeRepo := fakes.NewFakeLikeRepository()
	notificationRepo := fakes.NewFakeNotificationRepository()
	bucketRepo := fakes.NewFakeBucketRepository()

	svc := NewPostService(postRepo, userRepo, likeRepo, notificationRepo, bucketRepo, nil)

	user, err := userRepo.CreateUser(context.Background(), "testuser", "test@example.com", "password")
	require.NoError(t, err)

	err = os.Setenv("ENVIRONMENT", "test")
	if err != nil {
		return nil, nil, nil, nil, nil, nil, models.PublicUser{}
	}

	return svc, postRepo, userRepo, likeRepo, notificationRepo, bucketRepo, user
}

func TestNewPost(t *testing.T) {
	svc, postRepo, _, _, _, bucketRepo, user := setupTest(t)

	ctx := context.Background()
	text := "Hello world @testuser"
	imageKeymap := map[int]string{
		0: "test/posts/staging/1/images/123.jpg",
	}

	bucketRepo.SetObject(imageKeymap[0], []byte("test image data"))

	err := svc.NewPost(ctx, user, text, imageKeymap)
	assert.NoError(t, err)

	postIds, err := postRepo.GetPostIdsForUser(ctx, int(user.UserID), 10, 0)
	assert.NoError(t, err)
	assert.Len(t, postIds, 1)

	post, err := postRepo.GetPostById(ctx, int(postIds[0]))
	assert.NoError(t, err)
	assert.Equal(t, text, post.Text.String)
	assert.Equal(t, user.UserID, post.UserID)

	assert.Len(t, post.Facets, 1)
	assert.Equal(t, "mention", post.Facets[0].Type)
	assert.Equal(t, int(user.UserID), post.Facets[0].UserId)

	destinationKey := repositories.GetDestinationKey("test", user.UserID, post.PostID, imageKeymap[0])
	imageData, exists := bucketRepo.GetObject(destinationKey)
	assert.True(t, exists)
	assert.Equal(t, []byte("test image data"), imageData)

	_, exists = bucketRepo.GetObject(imageKeymap[0])
	assert.False(t, exists)

	images, err := postRepo.GetImagesForPost(ctx, int(post.PostID))
	assert.NoError(t, err)
	assert.Len(t, images, 1)
	assert.Equal(t, destinationKey, images[0].ImageBlobUrl)
}

func TestNewPresignedStagingUrl(t *testing.T) {
	svc, _, _, _, _, _, user := setupTest(t)

	ctx := context.Background()
	extension := "jpg"
	folder := "images"

	key, url, err := svc.NewPresignedStagingUrl(ctx, user, &extension, &folder)
	assert.NoError(t, err)
	assert.NotEmpty(t, key)
	assert.NotEmpty(t, url)
	assert.Contains(t, key, "test/posts/staging/1/images/")
	assert.Contains(t, key, ".jpg")
}

func TestGetPostById(t *testing.T) {
	svc, postRepo, _, _, _, bucketRepo, user := setupTest(t)

	ctx := context.Background()

	postContent := "Test post content"
	post, err := postRepo.InsertPost(ctx, int(user.UserID), postContent, nil)
	require.NoError(t, err)

	imageUrl := "test/posts/1/images/123.jpg"
	bucketRepo.SetObject(imageUrl, []byte("test image data"))
	_, err = postRepo.InsertImage(ctx, int(post.PostID), 500, 500, imageUrl, 0)
	require.NoError(t, err)

	detailedPost, err := svc.GetPostById(ctx, user, int(post.PostID))
	assert.NoError(t, err)
	assert.NotNil(t, detailedPost)

	assert.Equal(t, post.PostID, detailedPost.Post.PostID)
	assert.Equal(t, postContent, detailedPost.Post.Text.String)
	assert.Equal(t, user.UserID, detailedPost.User.UserID)
	assert.Equal(t, user.Username, detailedPost.User.Username)
	assert.Len(t, detailedPost.Images, 1)
	assert.Contains(t, detailedPost.Images[0].ImageBlobUrl, imageUrl)
}

func TestGetAllPosts(t *testing.T) {
	svc, postRepo, _, _, _, _, user := setupTest(t)

	ctx := context.Background()

	for i := 0; i < 5; i++ {
		_, err := postRepo.InsertPost(ctx, int(user.UserID), "Post content "+string(rune(i+48)), nil)
		require.NoError(t, err)
	}

	posts, err := svc.GetAllPosts(ctx, user, 10, 0)
	assert.NoError(t, err)
	assert.Len(t, *posts, 5)

	posts, err = svc.GetAllPosts(ctx, user, 2, 0)
	assert.NoError(t, err)
	assert.Len(t, *posts, 2)

	posts, err = svc.GetAllPosts(ctx, user, 2, 2)
	assert.NoError(t, err)
	assert.Len(t, *posts, 2)

	posts, err = svc.GetAllPosts(ctx, user, 2, 4)
	assert.NoError(t, err)
	assert.Len(t, *posts, 1)
}

func TestGetPostsByUserId(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, user := setupTest(t)

	ctx := context.Background()

	user2, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password")
	require.NoError(t, err)

	for i := 0; i < 3; i++ {
		_, err := postRepo.InsertPost(ctx, int(user.UserID), "User 1 post "+string(rune(i+48)), nil)
		require.NoError(t, err)
	}

	for i := 0; i < 2; i++ {
		_, err := postRepo.InsertPost(ctx, int(user2.UserID), "User 2 post "+string(rune(i+48)), nil)
		require.NoError(t, err)
	}

	posts, err := svc.GetPostsByUserId(ctx, user, int(user.UserID), 10, 0)
	assert.NoError(t, err)
	assert.Len(t, *posts, 3)

	posts, err = svc.GetPostsByUserId(ctx, user, int(user2.UserID), 10, 0)
	assert.NoError(t, err)
	assert.Len(t, *posts, 2)
}

func TestDeletePost(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, user := setupTest(t)

	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, int(user.UserID), "Test post for deletion", nil)
	require.NoError(t, err)

	err = svc.DeletePost(ctx, user, int(post.PostID))
	assert.NoError(t, err)

	_, err = postRepo.GetPostById(ctx, int(post.PostID))
	assert.Error(t, err)

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password")
	require.NoError(t, err)

	post2, err := postRepo.InsertPost(ctx, int(otherUser.UserID), "Other user's post", nil)
	require.NoError(t, err)

	err = svc.DeletePost(ctx, user, int(post2.PostID))
	assert.Error(t, err)

	_, err = postRepo.GetPostById(ctx, int(post2.PostID))
	assert.NoError(t, err)
}

func TestAddLikeToPost(t *testing.T) {
	svc, postRepo, userRepo, likeRepo, _, _, _ := setupTest(t)
	ctx := context.Background()

	postOwner, err := userRepo.CreateUser(ctx, "postOwner", "postowner@splajompy.com", "password")
	require.NoError(t, err)
	secondUser, err := userRepo.CreateUser(ctx, "otherUser", "otheruser@splajompy.com", "password")
	require.NoError(t, err)

	post0, err := postRepo.InsertPost(ctx, int(postOwner.UserID), "Test post for liking", nil)
	require.NoError(t, err)

	err = svc.AddLikeToPost(ctx, postOwner, int(post0.PostID))
	assert.NoError(t, err)
	err = svc.AddLikeToPost(ctx, secondUser, int(post0.PostID))
	assert.NoError(t, err)

	likes, err := likeRepo.GetLikesForPost(ctx, int(post0.PostID))
	assert.NoError(t, err)
	assert.Len(t, likes, 2)

	var foundPostOwner, foundSecondUser bool
	for _, like := range likes {
		if like.UserID == postOwner.UserID {
			foundPostOwner = true
		}
		if like.UserID == secondUser.UserID {
			foundSecondUser = true
		}
	}

	assert.True(t, foundPostOwner, "Post owner's like should be present")
	assert.True(t, foundSecondUser, "Second user's like should be present")
}

func TestRemoveLikeFromPost(t *testing.T) {
	svc, postRepo, userRepo, likeRepo, _, _, _ := setupTest(t)
	ctx := context.Background()

	postOwner, err := userRepo.CreateUser(ctx, "postOwner", "postowner@splajompy.com", "password")
	require.NoError(t, err)
	secondUser, err := userRepo.CreateUser(ctx, "otherUser", "otheruser@splajompy.com", "password")
	require.NoError(t, err)

	post0, err := postRepo.InsertPost(ctx, int(postOwner.UserID), "Test post for liking", nil)
	require.NoError(t, err)

	err = svc.AddLikeToPost(ctx, postOwner, int(post0.PostID))
	assert.NoError(t, err)
	err = svc.AddLikeToPost(ctx, secondUser, int(post0.PostID))
	assert.NoError(t, err)

	likes, err := likeRepo.GetLikesForPost(ctx, int(post0.PostID))
	assert.NoError(t, err)
	assert.Len(t, likes, 2)

	err = svc.RemoveLikeFromPost(ctx, postOwner, int(post0.PostID))
	assert.NoError(t, err)

	likes, err = likeRepo.GetLikesForPost(ctx, int(post0.PostID))
	assert.NoError(t, err)
	assert.Len(t, likes, 1)

	err = svc.RemoveLikeFromPost(ctx, secondUser, int(post0.PostID))
	assert.NoError(t, err)

	likes, err = likeRepo.GetLikesForPost(ctx, int(post0.PostID))
	assert.NoError(t, err)
	assert.Len(t, likes, 0)
}
