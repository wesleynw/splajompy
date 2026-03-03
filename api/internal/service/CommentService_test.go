package service_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/testutil"
)

type commentServiceTestEnv struct {
	svc            *service.CommentService
	postRepository repositories.PostRepository
	userRepository repositories.UserRepository
}

func setupCommentTest(t *testing.T) commentServiceTestEnv {
	t.Helper()
	testDb := testutil.StartPostgres(t)

	commentRepository := repositories.NewDBCommentRepository(testDb.Queries)
	postRepository := repositories.NewDBPostRepository(testDb.Queries)
	notificationRepository := repositories.NewDBNotificationRepository(testDb.Queries)
	userRepository := repositories.NewDBUserRepository(testDb.Queries)
	likeRepository := repositories.NewDBLikeRepository(testDb.Queries)

	svc := service.NewCommentService(commentRepository, postRepository, notificationRepository, userRepository, likeRepository)

	return commentServiceTestEnv{
		svc:            svc,
		postRepository: postRepository,
		userRepository: userRepository,
	}
}

func TestAddCommentToPost(t *testing.T) {
	env := setupCommentTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	post, err := env.postRepository.InsertPost(t.Context(), user0.UserID, "post0", nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	commentContent := "test comment"
	detailedComment, err := env.svc.AddCommentToPost(t.Context(), user0, post.PostID, commentContent)

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

	comment, err := env.svc.AddCommentToPost(t.Context(), user0, post.PostID, "test comment")
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

	comment, err := env.svc.AddCommentToPost(t.Context(), user1, post.PostID, "test comment")
	require.NoError(t, err)

	comments, err := env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Len(t, comments, 1)
	assert.Equal(t, comment.CommentID, comments[0].CommentID)

	err = env.userRepository.BlockUser(t.Context(), user0.UserID, user1.UserID)
	assert.NoError(t, err)

	comments, err = env.svc.GetCommentsByPostId(t.Context(), user0, post.PostID)
	assert.NoError(t, err)
	assert.Empty(t, comments)
}
