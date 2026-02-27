package service

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/testutil"
)

func setupCommentTest(t *testing.T) (*CommentService, repositories.CommentRepository, repositories.PostRepository, repositories.NotificationRepository, repositories.UserRepository, repositories.LikeRepository, models.PublicUser) {
	testDb := testutil.StartPostgres(t)

	commentRepository := repositories.NewDBCommentRepository(testDb.Queries)
	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	notificationRepository := repositories.NewDBNotificationRepository(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	likeRepository := repositories.NewDBLikeRepository(testDb.Queries)

	svc := NewCommentService(commentRepository, postRepository, notificationRepository, userRepository, likeRepository)

	user, err := userRepository.CreateUser(context.Background(), "testUser", "test@example.com", "password", "123")
	require.NoError(t, err)

	return svc, commentRepository, postRepository, notificationRepository, userRepository, likeRepository, user
}

func TestAddCommentToPost(t *testing.T) {
	svc, _, postRepository, _, _, _, user := setupCommentTest(t)

	post, err := postRepository.InsertPost(t.Context(), user.UserID, "Test post for comments", nil, nil, new(models.VisibilityTypeEnum))
	require.NoError(t, err)

	commentContent := "This is a test comment"
	detailedComment, err := svc.AddCommentToPost(t.Context(), user, post.PostID, commentContent)

	assert.NoError(t, err)
	assert.NotNil(t, detailedComment)
	assert.Equal(t, commentContent, detailedComment.Text)
	assert.Equal(t, user.UserID, detailedComment.UserID)
	assert.Equal(t, post.PostID, detailedComment.PostID)
	assert.False(t, detailedComment.IsLiked)
	assert.Equal(t, user, detailedComment.User)

	nonExistentPostID := 9999
	_, err = svc.AddCommentToPost(t.Context(), user, nonExistentPostID, "Comment on non-existent post")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unable to find post")
}

func TestGetCommentsByPostId(t *testing.T) {
	svc, _, postRepo, _, userRepo, _, user := setupCommentTest(t)

	post, err := postRepo.InsertPost(t.Context(), user.UserID, "Test post for getting comments", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	commenter, err := userRepo.CreateUser(t.Context(), "commenter", "commenter@example.com", "password", "123")
	require.NoError(t, err)

	commentContents := []string{
		"First comment",
		"Second comment",
		"Third comment",
	}

	for _, content := range commentContents {
		_, err := svc.AddCommentToPost(t.Context(), commenter, post.PostID, content)
		require.NoError(t, err)
	}

	comments, err := svc.GetCommentsByPostId(t.Context(), user, post.PostID)

	assert.NoError(t, err)
	assert.Len(t, comments, 3)

	commentTexts := make([]string, len(comments))
	for i, comment := range comments {
		commentTexts[i] = comment.Text
		assert.Equal(t, commenter.UserID, comment.UserID)
		assert.Equal(t, post.PostID, comment.PostID)
		assert.False(t, comment.IsLiked)
		assert.Equal(t, commenter.Username, comment.User.Username)
	}

	assert.ElementsMatch(t, commentContents, commentTexts)

	emptyPost, err := postRepo.InsertPost(t.Context(), user.UserID, "Empty post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	emptyComments, err := svc.GetCommentsByPostId(t.Context(), user, emptyPost.PostID)
	assert.NoError(t, err)
	assert.Len(t, emptyComments, 0)

	nonExistentPostID := 9999
	_, err = svc.GetCommentsByPostId(t.Context(), user, nonExistentPostID)
	assert.NoError(t, err)
	assert.Len(t, []models.DetailedComment{}, 0)
}

func TestCommentLikes(t *testing.T) {
	svc, _, postRepo, _, userRepo, _, user := setupCommentTest(t)

	post, err := postRepo.InsertPost(t.Context(), user.UserID, "Test post for comment likes", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	otherUser, err := userRepo.CreateUser(t.Context(), "otherUser", "other@example.com", "password", "123")
	require.NoError(t, err)

	comment, err := svc.AddCommentToPost(t.Context(), otherUser, post.PostID, "Comment to like")
	require.NoError(t, err)

	comments, err := svc.GetCommentsByPostId(t.Context(), otherUser, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.False(t, comments[0].IsLiked)

	err = svc.AddLikeToCommentById(t.Context(), user, post.PostID, comment.CommentID)
	assert.NoError(t, err)

	likes, err := svc.notificationRepository.GetNotificationsForUserId(t.Context(), otherUser.UserID, 0, 10)
	assert.NoError(t, err)

	assert.Len(t, likes, 1)
	assert.Equal(t, comment.CommentID, *likes[0].CommentID)
	assert.Equal(t, comment.UserID, likes[0].UserID)

	comments, err = svc.GetCommentsByPostId(t.Context(), user, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.True(t, comments[0].IsLiked)

	err = svc.RemoveLikeFromCommentById(t.Context(), otherUser, post.PostID, comment.CommentID)
	assert.NoError(t, err)

	comments, err = svc.GetCommentsByPostId(t.Context(), otherUser, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.False(t, comments[0].IsLiked)
}

func TestCommentCreatedTimestamp(t *testing.T) {
	svc, _, postRepo, _, _, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comment timestamp", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	beforeCreation := time.Now().Add(-1 * time.Second)
	comment, err := svc.AddCommentToPost(ctx, user, post.PostID, "Comment with timestamp")
	afterCreation := time.Now().Add(1 * time.Second)
	require.NoError(t, err)

	assert.True(t, comment.CreatedAt.After(beforeCreation))
	assert.True(t, comment.CreatedAt.Before(afterCreation))
}

func TestRemoveLikeFromComment_DeletesNotification(t *testing.T) {
	svc, commentRepo, postRepo, notificationRepo, userRepo, likeRepo, user := setupCommentTest(t)
	ctx := context.Background()

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := commentRepo.AddCommentToPost(ctx, otherUser.UserID, post.PostID, "Test comment", nil)
	require.NoError(t, err)

	commentID := comment.CommentID
	err = likeRepo.AddLike(ctx, user.UserID, post.PostID, &commentID)
	require.NoError(t, err)

	err = notificationRepo.InsertNotification(ctx, otherUser.UserID, &post.PostID, &commentID, nil, "@testUser liked your comment.", models.NotificationTypeLike, nil)
	require.NoError(t, err)

	err = svc.RemoveLikeFromCommentById(ctx, user, post.PostID, commentID)
	require.NoError(t, err)
}

func TestRemoveLikeFromComment_NoNotificationExists(t *testing.T) {
	svc, commentRepo, postRepo, _, userRepo, likeRepo, user := setupCommentTest(t)

	otherUser, err := userRepo.CreateUser(t.Context(), "otheruser", "other@example.com", "password", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(t.Context(), user.UserID, "Test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := commentRepo.AddCommentToPost(t.Context(), otherUser.UserID, post.PostID, "Test comment", nil)
	require.NoError(t, err)

	commentID := comment.CommentID
	err = likeRepo.AddLike(t.Context(), user.UserID, post.PostID, &commentID)
	require.NoError(t, err)

	err = svc.RemoveLikeFromCommentById(t.Context(), user, post.PostID, comment.CommentID)
	require.NoError(t, err)
}

func TestDeleteComment_UnauthorizedUser(t *testing.T) {
	svc, _, postRepo, _, userRepo, _, user := setupCommentTest(t)

	post, err := postRepo.InsertPost(t.Context(), user.UserID, "Test post for deletion", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	otherUser, err := userRepo.CreateUser(t.Context(), "otherUser", "other@example.com", "password", "123")
	require.NoError(t, err)

	comment, err := svc.AddCommentToPost(t.Context(), otherUser, post.PostID, "Comment to delete")
	require.NoError(t, err)

	err = svc.DeleteComment(t.Context(), user, comment.CommentID)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unable to delete comment")

	comments, err := svc.GetCommentsByPostId(t.Context(), user, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.Equal(t, comment.CommentID, comments[0].CommentID)
}

func TestNewCommentWithMention_DoesntSelfNotify(t *testing.T) {
	svc, _, postRepo, notificationRepo, userRepo, _, _ := setupCommentTest(t)
	ctx := context.Background()

	user0, err := userRepo.CreateUser(ctx, "user0", "user0@splajompy.com", "password123", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(ctx, user0.UserID, "Test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	commentText := "mentioning myself in a comment @user0"
	_, err = svc.AddCommentToPost(ctx, user0, post.PostID, commentText)
	require.NoError(t, err)

	notifications, err := notificationRepo.GetNotificationsForUserId(ctx, user0.UserID, 0, 10)
	require.NoError(t, err)

	assert.Len(t, notifications, 0)
}

func TestNewCommentWithMultipleMentions_DeduplicatesNotifications(t *testing.T) {
	svc, _, postRepo, notificationRepo, userRepo, _, _ := setupCommentTest(t)
	ctx := context.Background()

	user0, err := userRepo.CreateUser(ctx, "user0", "user0@splajompy.com", "password123", "123")
	require.NoError(t, err)
	user1, err := userRepo.CreateUser(ctx, "user1", "user1@splajompy.com", "password123", "123")
	require.NoError(t, err)
	user2, err := userRepo.CreateUser(ctx, "user2", "user2@splajompy.com", "password123", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(ctx, user0.UserID, "Test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	commentText := "mentioning multiple users in the comment @user1 @user1 @user1 @user2 @user2"
	_, err = svc.AddCommentToPost(ctx, user0, post.PostID, commentText)
	require.NoError(t, err)

	user1Notifications, err := notificationRepo.GetNotificationsForUserId(ctx, user1.UserID, 0, 10)
	require.NoError(t, err)
	assert.Len(t, user1Notifications, 1)

	user2Notifications, err := notificationRepo.GetNotificationsForUserId(ctx, user2.UserID, 0, 10)
	require.NoError(t, err)
	assert.Len(t, user2Notifications, 1)
}
