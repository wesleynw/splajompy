package service

import (
	"context"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories/fakes"
	"testing"
	"time"
)

func setupCommentTest(t *testing.T) (*CommentService, *fakes.FakeCommentRepository, *fakes.FakePostRepository, *fakes.FakeNotificationRepository, *fakes.FakeUserRepository, models.PublicUser) {
	commentRepo := fakes.NewFakeCommentRepository()
	postRepo := fakes.NewFakePostRepository()
	notificationRepo := fakes.NewFakeNotificationRepository()
	userRepo := fakes.NewFakeUserRepository()

	svc := NewCommentService(commentRepo, postRepo, notificationRepo, userRepo)

	user, err := userRepo.CreateUser(context.Background(), "testUser", "test@example.com", "password")
	require.NoError(t, err)

	return svc, commentRepo, postRepo, notificationRepo, userRepo, user
}

func TestAddCommentToPost(t *testing.T) {
	svc, _, postRepo, _, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comments", nil)
	require.NoError(t, err)

	commentContent := "This is a test comment"
	detailedComment, err := svc.AddCommentToPost(ctx, user, int(post.PostID), commentContent)

	assert.NoError(t, err)
	assert.NotNil(t, detailedComment)
	assert.Equal(t, commentContent, detailedComment.Text)
	assert.Equal(t, user.UserID, detailedComment.UserID)
	assert.Equal(t, int(post.PostID), detailedComment.PostID)
	assert.False(t, detailedComment.IsLiked)
	assert.Equal(t, user, detailedComment.User)

	nonExistentPostID := 9999
	_, err = svc.AddCommentToPost(ctx, user, nonExistentPostID, "Comment on non-existent post")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unable to find post")
}

func TestGetCommentsByPostId(t *testing.T) {
	svc, _, postRepo, _, userRepo, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for getting comments", nil)
	require.NoError(t, err)

	commenter, err := userRepo.CreateUser(ctx, "commenter", "commenter@example.com", "password")
	require.NoError(t, err)

	commentContents := []string{
		"First comment",
		"Second comment",
		"Third comment",
	}

	for _, content := range commentContents {
		_, err := svc.AddCommentToPost(ctx, commenter, int(post.PostID), content)
		require.NoError(t, err)
	}

	comments, err := svc.GetCommentsByPostId(ctx, user, int(post.PostID))

	assert.NoError(t, err)
	assert.Len(t, comments, 3)

	commentTexts := make([]string, len(comments))
	for i, comment := range comments {
		commentTexts[i] = comment.Text
		assert.Equal(t, commenter.UserID, comment.UserID)
		assert.Equal(t, int(post.PostID), comment.PostID)
		assert.False(t, comment.IsLiked)
		assert.Equal(t, commenter.Username, comment.User.Username)
	}

	assert.ElementsMatch(t, commentContents, commentTexts)

	emptyPost, err := postRepo.InsertPost(ctx, user.UserID, "Empty post", nil)
	require.NoError(t, err)

	emptyComments, err := svc.GetCommentsByPostId(ctx, user, int(emptyPost.PostID))
	assert.NoError(t, err)
	assert.Len(t, emptyComments, 0)

	nonExistentPostID := 9999
	_, err = svc.GetCommentsByPostId(ctx, user, nonExistentPostID)
	assert.NoError(t, err)
	assert.Len(t, []models.DetailedComment{}, 0)
}

func TestCommentLikes(t *testing.T) {
	svc, _, postRepo, _, userRepo, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comment likes", nil)
	require.NoError(t, err)

	otherUser, err := userRepo.CreateUser(ctx, "otherUser", "other@example.com", "password")
	require.NoError(t, err)

	comment, err := svc.AddCommentToPost(ctx, otherUser, int(post.PostID), "Comment to like")
	require.NoError(t, err)

	comments, err := svc.GetCommentsByPostId(ctx, otherUser, int(post.PostID))
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.False(t, comments[0].IsLiked)

	err = svc.AddLikeToCommentById(ctx, user, int(post.PostID), comment.CommentID)
	assert.NoError(t, err)

	likes, err := svc.notificationRepo.GetNotificationsForUserId(ctx, otherUser.UserID, 0, 10)
	assert.NoError(t, err)

	assert.Len(t, likes, 1)
	assert.Equal(t, comment.CommentID, *likes[0].CommentID)
	assert.Equal(t, comment.UserID, likes[0].UserID)

	comments, err = svc.GetCommentsByPostId(ctx, user, int(post.PostID))
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.True(t, comments[0].IsLiked)

	err = svc.RemoveLikeFromCommentById(ctx, otherUser, int(post.PostID), comment.CommentID)
	assert.NoError(t, err)

	comments, err = svc.GetCommentsByPostId(ctx, otherUser, int(post.PostID))
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.False(t, comments[0].IsLiked)
}

func TestCommentCreatedTimestamp(t *testing.T) {
	svc, _, postRepo, _, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comment timestamp", nil)
	require.NoError(t, err)

	beforeCreation := time.Now().Add(-1 * time.Second)
	comment, err := svc.AddCommentToPost(ctx, user, int(post.PostID), "Comment with timestamp")
	afterCreation := time.Now().Add(1 * time.Second)
	require.NoError(t, err)

	assert.True(t, comment.CreatedAt.After(beforeCreation))
	assert.True(t, comment.CreatedAt.Before(afterCreation))
}
