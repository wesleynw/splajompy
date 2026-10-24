package like_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/like"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/testutil"
	"splajompy.com/api/v2/internal/user"
)

type testEnv struct {
	likeRepository    like.Store
	postRepository    post.Store
	commentRepository comment.Store
	userRepository    user.Store
}

func setupTest(t *testing.T) testEnv {
	t.Helper()
	db := testutil.StartPostgres(t)

	return testEnv{
		likeRepository:    db.LikeRepository,
		postRepository:    db.PostRepository,
		commentRepository: db.CommentRepository,
		userRepository:    db.UserRepository,
	}
}

func TestPostAndCommentLiking_Succeeds(t *testing.T) {
	env := setupTest(t)

	user0 := testutil.CreateTestUser(t, env.userRepository, "user0")

	post0, err := env.postRepository.InsertPost(t.Context(), user0.UserID, new("test"), nil, nil, new(models.VisibilityPublic))
	require.NoError(t, err)

	comment0, err := env.commentRepository.AddCommentToPost(t.Context(), user0.UserID, post0.PostID, "test comment", nil, nil)
	require.NoError(t, err)

	is_liked, err := env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	err = env.likeRepository.AddLike(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)
	assert.Equal(t, true, is_liked)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	err = env.likeRepository.RemoveLike(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	err = env.likeRepository.AddLike(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)
	assert.Equal(t, true, is_liked)

	err = env.likeRepository.RemoveLike(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)
	assert.Equal(t, false, is_liked)

	err = env.likeRepository.AddLike(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)

	err = env.likeRepository.AddLike(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, nil)
	require.NoError(t, err)
	assert.Equal(t, true, is_liked)

	is_liked, err = env.likeRepository.IsLiked(t.Context(), user0.UserID, post0.PostID, &comment0.CommentID)
	require.NoError(t, err)
	assert.Equal(t, true, is_liked)
}
