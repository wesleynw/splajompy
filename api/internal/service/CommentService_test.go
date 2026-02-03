package service

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/repositories/fakes"
)

func setupCommentTest(t *testing.T) (*CommentService, *fakes.FakeCommentRepository, *fakes.FakePostRepository, *fakes.FakeNotificationRepository, repositories.UserRepository, *fakes.FakeLikeRepository, models.PublicUser) {
	commentRepo := fakes.NewFakeCommentRepository()
	postRepo := fakes.NewFakePostRepository()
	notificationRepo := fakes.NewFakeNotificationRepository()
	userRepo := fakes.NewFakeUserRepository()
	likeRepo := fakes.NewFakeLikeRepository()

	svc := NewCommentService(commentRepo, postRepo, notificationRepo, userRepo, likeRepo)

	user, err := userRepo.CreateUser(context.Background(), "testUser", "test@example.com", "password", "123")
	require.NoError(t, err)

	return svc, commentRepo, postRepo, notificationRepo, userRepo, likeRepo, user
}

func TestAddCommentToPost(t *testing.T) {
	svc, _, postRepo, _, _, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comments", nil, nil, nil)
	require.NoError(t, err)

	commentContent := "This is a test comment"
	detailedComment, err := svc.AddCommentToPost(ctx, user, post.PostID, commentContent)

	assert.NoError(t, err)
	assert.NotNil(t, detailedComment)
	assert.Equal(t, commentContent, detailedComment.Text)
	assert.Equal(t, user.UserID, detailedComment.UserID)
	assert.Equal(t, post.PostID, detailedComment.PostID)
	assert.False(t, detailedComment.IsLiked)
	assert.Equal(t, user, detailedComment.User)

	nonExistentPostID := 9999
	_, err = svc.AddCommentToPost(ctx, user, nonExistentPostID, "Comment on non-existent post")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unable to find post")
}

func TestGetCommentsByPostId(t *testing.T) {
	svc, _, postRepo, _, userRepo, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for getting comments", nil, nil, nil)
	require.NoError(t, err)

	commenter, err := userRepo.CreateUser(ctx, "commenter", "commenter@example.com", "password", "123")
	require.NoError(t, err)

	commentContents := []string{
		"First comment",
		"Second comment",
		"Third comment",
	}

	for _, content := range commentContents {
		_, err := svc.AddCommentToPost(ctx, commenter, post.PostID, content)
		require.NoError(t, err)
	}

	comments, err := svc.GetCommentsByPostId(ctx, user, post.PostID)

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

	emptyPost, err := postRepo.InsertPost(ctx, user.UserID, "Empty post", nil, nil, nil)
	require.NoError(t, err)

	emptyComments, err := svc.GetCommentsByPostId(ctx, user, emptyPost.PostID)
	assert.NoError(t, err)
	assert.Len(t, emptyComments, 0)

	nonExistentPostID := 9999
	_, err = svc.GetCommentsByPostId(ctx, user, nonExistentPostID)
	assert.NoError(t, err)
	assert.Len(t, []models.DetailedComment{}, 0)
}

func TestCommentLikes(t *testing.T) {
	svc, _, postRepo, _, userRepo, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comment likes", nil, nil, nil)
	require.NoError(t, err)

	otherUser, err := userRepo.CreateUser(ctx, "otherUser", "other@example.com", "password", "123")
	require.NoError(t, err)

	comment, err := svc.AddCommentToPost(ctx, otherUser, post.PostID, "Comment to like")
	require.NoError(t, err)

	comments, err := svc.GetCommentsByPostId(ctx, otherUser, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.False(t, comments[0].IsLiked)

	err = svc.AddLikeToCommentById(ctx, user, post.PostID, comment.CommentID)
	assert.NoError(t, err)

	likes, err := svc.notificationRepository.GetNotificationsForUserId(ctx, otherUser.UserID, 0, 10)
	assert.NoError(t, err)

	assert.Len(t, likes, 1)
	assert.Equal(t, comment.CommentID, *likes[0].CommentID)
	assert.Equal(t, comment.UserID, likes[0].UserID)

	comments, err = svc.GetCommentsByPostId(ctx, user, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.True(t, comments[0].IsLiked)

	err = svc.RemoveLikeFromCommentById(ctx, otherUser, post.PostID, comment.CommentID)
	assert.NoError(t, err)

	comments, err = svc.GetCommentsByPostId(ctx, otherUser, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.False(t, comments[0].IsLiked)
}

func TestCommentCreatedTimestamp(t *testing.T) {
	svc, _, postRepo, _, _, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for comment timestamp", nil, nil, nil)
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

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post", nil, nil, nil)
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

	assert.Equal(t, 0, notificationRepo.GetNotificationCount(otherUser.UserID))
}

func TestRemoveLikeFromComment_KeepsOldNotification(t *testing.T) {
	svc, commentRepo, postRepo, notificationRepo, userRepo, likeRepo, user := setupCommentTest(t)
	ctx := context.Background()

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post", nil, nil, nil)
	require.NoError(t, err)

	comment, err := commentRepo.AddCommentToPost(ctx, otherUser.UserID, post.PostID, "Test comment", nil)
	require.NoError(t, err)

	commentID := comment.CommentID
	err = likeRepo.AddLike(ctx, user.UserID, post.PostID, &commentID)
	require.NoError(t, err)

	oldTime := time.Now().Add(-10 * time.Minute)
	notification := queries.Notification{
		UserID:           otherUser.UserID,
		PostID:           &post.PostID,
		CommentID:        &comment.CommentID,
		Message:          "@testUser liked your comment.",
		NotificationType: "like",
		Viewed:           false,
		CreatedAt:        pgtype.Timestamp{Time: oldTime, Valid: true},
	}
	notificationRepo.AddNotification(notification)

	err = svc.RemoveLikeFromCommentById(ctx, user, post.PostID, comment.CommentID)
	require.NoError(t, err)

	assert.Equal(t, 1, notificationRepo.GetNotificationCount(otherUser.UserID))
}

func TestRemoveLikeFromComment_NoNotificationExists(t *testing.T) {
	svc, commentRepo, postRepo, notificationRepo, userRepo, likeRepo, user := setupCommentTest(t)
	ctx := context.Background()

	otherUser, err := userRepo.CreateUser(ctx, "otheruser", "other@example.com", "password", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post", nil, nil, nil)
	require.NoError(t, err)

	comment, err := commentRepo.AddCommentToPost(ctx, otherUser.UserID, post.PostID, "Test comment", nil)
	require.NoError(t, err)

	commentID := comment.CommentID
	err = likeRepo.AddLike(ctx, user.UserID, post.PostID, &commentID)
	require.NoError(t, err)

	err = svc.RemoveLikeFromCommentById(ctx, user, post.PostID, comment.CommentID)
	require.NoError(t, err)

	assert.Equal(t, 0, notificationRepo.GetNotificationCount(otherUser.UserID))
}

func TestDeleteComment_UnauthorizedUser(t *testing.T) {
	svc, _, postRepo, _, userRepo, _, user := setupCommentTest(t)
	ctx := context.Background()

	post, err := postRepo.InsertPost(ctx, user.UserID, "Test post for deletion", nil, nil, nil)
	require.NoError(t, err)

	otherUser, err := userRepo.CreateUser(ctx, "otherUser", "other@example.com", "password", "123")
	require.NoError(t, err)

	comment, err := svc.AddCommentToPost(ctx, otherUser, post.PostID, "Comment to delete")
	require.NoError(t, err)

	err = svc.DeleteComment(ctx, user, comment.CommentID)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unable to delete comment")

	comments, err := svc.GetCommentsByPostId(ctx, user, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.Equal(t, comment.CommentID, comments[0].CommentID)
}

func TestNewCommentWithMention_DoesntSelfNotify(t *testing.T) {
	svc, _, postRepo, notificationRepo, userRepo, _, _ := setupCommentTest(t)
	ctx := context.Background()

	user0, err := userRepo.CreateUser(ctx, "user0", "user0@splajompy.com", "password123", "123")
	require.NoError(t, err)

	post, err := postRepo.InsertPost(ctx, user0.UserID, "Test post", nil, nil, nil)
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

	post, err := postRepo.InsertPost(ctx, user0.UserID, "Test post", nil, nil, nil)
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
