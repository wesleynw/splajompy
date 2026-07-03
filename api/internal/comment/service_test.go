package comment_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/testutil"
	"splajompy.com/api/v2/internal/user"
)

type commentServiceTestEnv struct {
	svc            *comment.Service
	userSvc        *user.Service
	postRepository post.Store
	userRepository user.Store
}

func setupCommentTest(t *testing.T) commentServiceTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)

	notificationService := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	svc := comment.NewService(&db.CommentRepository, db.PostRepository, *notificationService, db.UserRepository, db.LikeRepository, db.BucketRepository)
	userSvc := user.NewUserService(db.UserRepository, *notificationService, nil)

	return commentServiceTestEnv{
		svc:            svc,
		userSvc:        userSvc,
		postRepository: db.PostRepository,
		userRepository: db.UserRepository,
	}
}

func TestAddCommentToPost(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "post0", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	commentContent := "test comment"
	detailedComment, err := env.svc.AddCommentToPost(t.Context(), user0, post.PostID, commentContent, nil)

	assert.NoError(t, err)
	assert.NotNil(t, detailedComment)
	assert.Equal(t, commentContent, detailedComment.Text)
	assert.Equal(t, user0.UserID, detailedComment.UserID)
	assert.Equal(t, post.PostID, detailedComment.PostID)
	assert.False(t, detailedComment.IsLiked)
	assert.Equal(t, user0, detailedComment.User)
}

func TestDeleteComment_UnauthorizedUser(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := env.svc.AddCommentToPost(t.Context(), user0, post.PostID, "test comment", nil)
	require.NoError(t, err)

	err = env.svc.DeleteComment(t.Context(), user1, comment.CommentID)
	assert.Error(t, err)

	comments, err := env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.Equal(t, comment.CommentID, comments[0].CommentID)
}

func TestGetComments_DoesNotReturnBlockedUserComments(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := env.svc.AddCommentToPost(t.Context(), user1, post.PostID, "test comment", nil)
	require.NoError(t, err)

	comments, err := env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.Equal(t, comment.CommentID, comments[0].CommentID)

	err = env.userSvc.BlockUser(t.Context(), user0, user1.UserID)
	assert.NoError(t, err)

	comments, err = env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Empty(t, comments)
}

func TestGetComments_DoesNotReturnMutedUserComments(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment, err := env.svc.AddCommentToPost(t.Context(), user1, post.PostID, "test comment", nil)
	require.NoError(t, err)

	comments, err := env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.Equal(t, comment.CommentID, comments[0].CommentID)

	err = env.userSvc.MuteUser(t.Context(), user0, user1.UserID)
	assert.NoError(t, err)

	comments, err = env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Empty(t, comments)
}

func TestGetComments_WithImage(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	images := map[int]models.ImageData{
		0: {S3Key: "images/photo1.jpg", Width: 1920, Height: 1080},
	}

	_, err = env.svc.AddCommentToPost(t.Context(), user0, post.PostID, "test comment", images)
	require.NoError(t, err)

	comments, err := env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)

	assert.NotNil(t, comments[0].Images)
	assert.Len(t, comments[0].Images, 1)
}

func TestGetComments_DoesNotReturnBlockingUserComments(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")
	user1 := testutil.CreateTestUser(t, env.userRepository, "user1")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "test post", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	_, err = env.svc.AddCommentToPost(t.Context(), user1, post.PostID, "test comment", nil)

	comments, err := env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	require.NoError(t, err)
	assert.Len(t, comments, 1)

	err = env.userRepository.BlockUser(t.Context(), user1.UserID, user0.UserID)

	comments, err = env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	require.NoError(t, err)
	assert.Empty(t, comments)
}
