package service

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"os"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/repositories/fakes"
	"testing"
	"time"
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
	imageKeymap := map[int]models.ImageData{
		0: {
			S3Key:  "test/posts/staging/1/images/123.jpg",
			Width:  1000,
			Height: 750,
		},
	}

	bucketRepo.SetObject(imageKeymap[0].S3Key, []byte("test image data"))

	err := svc.NewPost(ctx, user, text, imageKeymap, nil)
	assert.NoError(t, err)

	postIds, err := postRepo.GetPostIdsForUser(ctx, user.UserID, 10, 0)
	assert.NoError(t, err)
	assert.Len(t, postIds, 1)

	post, err := postRepo.GetPostById(ctx, postIds[0])
	assert.NoError(t, err)
	assert.Equal(t, text, post.Text)
	assert.Equal(t, user.UserID, int(post.UserID))

	assert.Len(t, post.Facets, 1)
	assert.Equal(t, "mention", post.Facets[0].Type)
	assert.Equal(t, user.UserID, post.Facets[0].UserId)

	destinationKey := repositories.GetDestinationKey("test", user.UserID, post.PostID, imageKeymap[0].S3Key)
	imageData, exists := bucketRepo.GetObject(destinationKey)
	assert.True(t, exists)
	assert.Equal(t, []byte("test image data"), imageData)

	_, exists = bucketRepo.GetObject(imageKeymap[0].S3Key)
	assert.False(t, exists)

	images, err := postRepo.GetImagesForPost(ctx, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, images, 1)
	assert.Equal(t, destinationKey, images[0].ImageBlobUrl)
	assert.Equal(t, int32(1000), images[0].Width)
	assert.Equal(t, int32(750), images[0].Height)
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
	post, err := postRepo.InsertPost(ctx, user.UserID, postContent, nil, nil)
	require.NoError(t, err)

	imageUrl := "test/posts/1/images/123.jpg"
	bucketRepo.SetObject(imageUrl, []byte("test image data"))
	_, err = postRepo.InsertImage(ctx, post.PostID, 500, 500, imageUrl, 0)
	require.NoError(t, err)

	detailedPost, err := svc.GetPostById(ctx, user, post.PostID)
	assert.NoError(t, err)
	assert.NotNil(t, detailedPost)

	assert.Equal(t, post.PostID, detailedPost.Post.PostID)
	assert.Equal(t, postContent, detailedPost.Post.Text)
	assert.Equal(t, user.UserID, detailedPost.User.UserID)
	assert.Equal(t, user.Username, detailedPost.User.Username)
	assert.Len(t, detailedPost.Images, 1)
	assert.Contains(t, detailedPost.Images[0].ImageBlobUrl, imageUrl)
}

func TestGetAllPosts(t *testing.T) {
	svc, postRepo, _, _, _, _, user := setupTest(t)

	ctx := context.Background()

	for i := 0; i < 5; i++ {
		_, err := postRepo.InsertPost(ctx, user.UserID, "Post content "+string(rune(i+48)), nil, nil)
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
		_, err := postRepo.InsertPost(ctx, user.UserID, "User 1 post "+string(rune(i+48)), nil, nil)
		require.NoError(t, err)
	}

	for i := 0; i < 2; i++ {
		_, err := postRepo.InsertPost(ctx, user2.UserID, "User 2 post "+string(rune(i+48)), nil, nil)
		require.NoError(t, err)
	}

	posts, err := svc.GetPostsByUserId(ctx, user, user.UserID, 10, 0)
	assert.NoError(t, err)
	assert.Len(t, *posts, 3)

	posts, err = svc.GetPostsByUserId(ctx, user, user2.UserID, 10, 0)
	assert.NoError(t, err)
	assert.Len(t, *posts, 2)
}

func TestDeletePost(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, user := setupTest(t)

	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for deletion", nil, nil)
	require.NoError(t, err)

	err = svc.DeletePost(ctx, user, post.PostID)
	assert.NoError(t, err)

	_, err = postRepo.GetPostById(ctx, post.PostID)
	assert.Error(t, err)

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password")
	require.NoError(t, err)

	post2, err := postRepo.InsertPost(ctx, otherUser.UserID, "Other user's post", nil, nil)
	require.NoError(t, err)

	err = svc.DeletePost(ctx, user, post2.PostID)
	assert.Error(t, err)

	_, err = postRepo.GetPostById(ctx, post2.PostID)
	assert.NoError(t, err)
}

func TestAddLikeToPost(t *testing.T) {
	svc, postRepo, userRepo, likeRepo, _, _, _ := setupTest(t)
	ctx := context.Background()

	postOwner, err := userRepo.CreateUser(ctx, "postOwner", "postowner@splajompy.com", "password")
	require.NoError(t, err)
	secondUser, err := userRepo.CreateUser(ctx, "otherUser", "otheruser@splajompy.com", "password")
	require.NoError(t, err)

	post0, err := postRepo.InsertPost(ctx, postOwner.UserID, "Test post for liking", nil, nil)
	require.NoError(t, err)

	err = svc.AddLikeToPost(ctx, postOwner, post0.PostID)
	assert.NoError(t, err)
	err = svc.AddLikeToPost(ctx, secondUser, post0.PostID)
	assert.NoError(t, err)

	likes, err := likeRepo.GetLikesForPost(ctx, post0.PostID)
	assert.NoError(t, err)
	assert.Len(t, likes, 2)

	var foundPostOwner, foundSecondUser bool
	for _, like := range likes {
		if int(like.UserID) == postOwner.UserID {
			foundPostOwner = true
		}
		if int(like.UserID) == secondUser.UserID {
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

	post0, err := postRepo.InsertPost(ctx, postOwner.UserID, "Test post for liking", nil, nil)
	require.NoError(t, err)

	err = svc.AddLikeToPost(ctx, postOwner, post0.PostID)
	assert.NoError(t, err)
	err = svc.AddLikeToPost(ctx, secondUser, post0.PostID)
	assert.NoError(t, err)

	likes, err := likeRepo.GetLikesForPost(ctx, post0.PostID)
	assert.NoError(t, err)
	assert.Len(t, likes, 2)

	err = svc.RemoveLikeFromPost(ctx, postOwner, post0.PostID)
	assert.NoError(t, err)

	likes, err = likeRepo.GetLikesForPost(ctx, post0.PostID)
	assert.NoError(t, err)
	assert.Len(t, likes, 1)

	err = svc.RemoveLikeFromPost(ctx, secondUser, post0.PostID)
	assert.NoError(t, err)

	likes, err = likeRepo.GetLikesForPost(ctx, post0.PostID)
	assert.NoError(t, err)
	assert.Len(t, likes, 0)
}

func TestGetPostWithPoll_ReturnsEmptyPoll(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, currentUser := setupTest(t)
	ctx := context.Background()

	user, err := userRepo.CreateUser(ctx, "test1", "testuser@splajompy.com", "password123")
	require.NoError(t, err)

	attributes := db.Attributes{Poll: db.Poll{
		Title: "is this test passing?",
		Options: []string{
			"yes", "no",
		},
	}}

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for vote on saving", nil, &attributes)
	require.NoError(t, err)

	updatedPost, err := svc.GetPostById(ctx, currentUser, post.PostID)
	require.NoError(t, err)

	require.NotNil(t, updatedPost)
	require.NotNil(t, updatedPost.Poll)
	poll := updatedPost.Poll

	assert.NotNil(t, poll)
	assert.Equal(t, poll.Title, "is this test passing?")
	assert.Equal(t, poll.VoteTotal, 0)
	assert.Nil(t, poll.CurrentUserVote)
	assert.Equal(t, poll.Options[0].Title, "yes")
	assert.Equal(t, poll.Options[1].Title, "no")
	assert.Equal(t, poll.Options[0].VoteTotal, 0)
	assert.Equal(t, poll.Options[1].VoteTotal, 0)
}

func TestVoteOnPoll_NegativeOptionIndex_ReturnsError(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, currentUser := setupTest(t)
	ctx := context.Background()

	user, err := userRepo.CreateUser(ctx, "test1", "testuser@splajompy.com", "password123")
	require.NoError(t, err)

	attributes := db.Attributes{Poll: db.Poll{
		Title: "is this test passing?",
		Options: []string{
			"yes", "no",
		},
	}}

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for vote on saving", nil, &attributes)
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, currentUser, post.PostID+1, -10)
	assert.Error(t, err)
}

func TestVoteOnPoll_Nonexistent_ReturnsError(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, currentUser := setupTest(t)
	ctx := context.Background()

	user, err := userRepo.CreateUser(ctx, "test1", "testuser@splajompy.com", "password123")
	require.NoError(t, err)

	attributes := db.Attributes{Poll: db.Poll{
		Title: "is this test passing?",
		Options: []string{
			"yes", "no",
		},
	}}

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for vote on saving", nil, &attributes)
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, currentUser, post.PostID+1, 2)
	assert.Error(t, err)
}

func TestVoteOnPoll_InvalidOptionIndex_ReturnsError(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, currentUser := setupTest(t)
	ctx := context.Background()

	user, err := userRepo.CreateUser(ctx, "test1", "testuser@splajompy.com", "password123")
	require.NoError(t, err)

	attributes := db.Attributes{Poll: db.Poll{
		Title: "is this test passing?",
		Options: []string{
			"yes", "no",
		},
	}}

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for vote on saving", nil, &attributes)
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, currentUser, post.PostID, 2)
	assert.Error(t, err)

	updatedPost, err := svc.GetPostById(ctx, currentUser, post.PostID)
	require.NoError(t, err)

	require.NotNil(t, updatedPost)
	require.NotNil(t, updatedPost.Poll)

	assert.Equal(t, updatedPost.Poll.Title, "is this test passing?")
	assert.Equal(t, updatedPost.Poll.VoteTotal, 0)
	assert.Nil(t, updatedPost.Poll.CurrentUserVote)
	assert.Equal(t, updatedPost.Poll.Options[0].Title, "yes")
	assert.Equal(t, updatedPost.Poll.Options[1].Title, "no")
	assert.Equal(t, updatedPost.Poll.Options[0].VoteTotal, 0)
	assert.Equal(t, updatedPost.Poll.Options[1].VoteTotal, 0)
}

func TestVoteOnPoll_SavesVote(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, currentUser := setupTest(t)
	ctx := context.Background()

	user, err := userRepo.CreateUser(ctx, "test1", "testuser@splajompy.com", "password123")
	require.NoError(t, err)

	poll := db.Poll{
		Title: "is this test passing?",
		Options: []string{
			"yes", "no",
		},
	}

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for vote on saving", nil, &db.Attributes{Poll: poll})
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, currentUser, post.PostID, 0)
	require.NoError(t, err)

	updatedPost, err := svc.GetPostById(ctx, currentUser, post.PostID)
	require.NoError(t, err)

	require.NotNil(t, updatedPost)
	require.NotNil(t, updatedPost.Poll)

	assert.Equal(t, updatedPost.Poll.Title, "is this test passing?")
	assert.Equal(t, updatedPost.Poll.VoteTotal, 1)
	assert.Equal(t, *updatedPost.Poll.CurrentUserVote, 0)
	assert.Equal(t, updatedPost.Poll.Options[0].Title, "yes")
	assert.Equal(t, updatedPost.Poll.Options[1].Title, "no")
	assert.Equal(t, updatedPost.Poll.Options[0].VoteTotal, 1)
	assert.Equal(t, updatedPost.Poll.Options[1].VoteTotal, 0)
}

func TestVoteOnPoll_SavesVote_Multi(t *testing.T) {
	svc, postRepo, userRepo, _, _, _, currentUser := setupTest(t)
	ctx := context.Background()

	user0, err := userRepo.CreateUser(ctx, "test0", "testuser0@splajompy.com", "password123")
	require.NoError(t, err)
	user1, err := userRepo.CreateUser(ctx, "test1", "testuser1@splajompy.com", "password123")
	require.NoError(t, err)
	user2, err := userRepo.CreateUser(ctx, "test2", "testuser2@splajompy.com", "password123")
	require.NoError(t, err)

	poll := db.Poll{
		Title: "is this test passing?",
		Options: []string{
			"yes", "no",
		},
	}

	post, err := postRepo.InsertPost(ctx, user0.UserID, "Test post for vote on saving", nil, &db.Attributes{Poll: poll})
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, currentUser, post.PostID, 1)
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, user0, post.PostID, 0)
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, user1, post.PostID, 0)
	require.NoError(t, err)

	err = svc.VoteOnPoll(ctx, user2, post.PostID, 0)
	require.NoError(t, err)

	updatedPost, err := svc.GetPostById(ctx, currentUser, post.PostID)
	require.NoError(t, err)

	require.NotNil(t, updatedPost)
	require.NotNil(t, updatedPost.Poll)

	assert.Equal(t, updatedPost.Poll.Title, "is this test passing?")
	assert.Equal(t, updatedPost.Poll.VoteTotal, 4)
	assert.Equal(t, *updatedPost.Poll.CurrentUserVote, 1)
	assert.Equal(t, updatedPost.Poll.Options[0].Title, "yes")
	assert.Equal(t, updatedPost.Poll.Options[1].Title, "no")
	assert.Equal(t, updatedPost.Poll.Options[0].VoteTotal, 3)
	assert.Equal(t, updatedPost.Poll.Options[1].VoteTotal, 1)
}

func TestRemoveLikeFromPost_DeletesRecentNotification(t *testing.T) {
	svc, _, userRepo, likeRepo, notificationRepo, _, user := setupTest(t)
	ctx := context.Background()

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password")
	require.NoError(t, err)

	post, err := svc.postRepository.InsertPost(ctx, otherUser.UserID, "Test post", nil, nil)
	require.NoError(t, err)

	err = likeRepo.AddLike(ctx, user.UserID, post.PostID, true)
	require.NoError(t, err)

	err = notificationRepo.InsertNotification(ctx, otherUser.UserID, &post.PostID, nil, nil, "@testuser liked your post.", models.NotificationTypeLike)
	require.NoError(t, err)

	err = svc.RemoveLikeFromPost(ctx, user, post.PostID)
	require.NoError(t, err)

	assert.Equal(t, 0, notificationRepo.GetNotificationCount(otherUser.UserID))
}

func TestRemoveLikeFromPost_KeepsOldNotification(t *testing.T) {
	svc, _, userRepo, likeRepo, notificationRepo, _, user := setupTest(t)
	ctx := context.Background()

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password")
	require.NoError(t, err)

	post, err := svc.postRepository.InsertPost(ctx, otherUser.UserID, "Test post", nil, nil)
	require.NoError(t, err)

	err = likeRepo.AddLike(ctx, user.UserID, post.PostID, true)
	require.NoError(t, err)

	oldTime := time.Now().Add(-10 * time.Minute)
	notification := queries.Notification{
		UserID:           int32(otherUser.UserID),
		PostID:           pgtype.Int4{Int32: int32(post.PostID), Valid: true},
		Message:          "@testuser liked your post.",
		NotificationType: "like",
		Viewed:           false,
		CreatedAt:        pgtype.Timestamp{Time: oldTime, Valid: true},
	}
	notificationRepo.AddNotification(notification)

	err = svc.RemoveLikeFromPost(ctx, user, post.PostID)
	require.NoError(t, err)

	assert.Equal(t, 1, notificationRepo.GetNotificationCount(otherUser.UserID))
}

func TestRemoveLikeFromPost_NoNotificationExists(t *testing.T) {
	svc, _, userRepo, likeRepo, notificationRepo, _, user := setupTest(t)
	ctx := context.Background()

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password")
	require.NoError(t, err)

	post, err := svc.postRepository.InsertPost(ctx, otherUser.UserID, "Test post", nil, nil)
	require.NoError(t, err)

	err = likeRepo.AddLike(ctx, user.UserID, post.PostID, true)
	require.NoError(t, err)

	err = svc.RemoveLikeFromPost(ctx, user, post.PostID)
	require.NoError(t, err)

	assert.Equal(t, 0, notificationRepo.GetNotificationCount(otherUser.UserID))
}
