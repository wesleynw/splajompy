package fakes

import (
	"context"
	"errors"
	"strconv"
	"sync"

	"splajompy.com/api/v2/internal/db/queries"
)

type likeKey struct {
	postID    int
	commentID int // 0 means no comment (post like), >0 means comment like
}

type FakeLikeRepository struct {
	Likes map[likeKey]map[int]bool // (postID, commentID) -> userID -> liked
	mutex sync.RWMutex
}

func NewFakeLikeRepository() *FakeLikeRepository {
	return &FakeLikeRepository{
		Likes: make(map[likeKey]map[int]bool),
	}
}

func (r *FakeLikeRepository) AddLike(_ context.Context, userId int, postId int, commentId *int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	commentIdValue := 0
	if commentId != nil {
		commentIdValue = *commentId
	}
	key := likeKey{postID: postId, commentID: commentIdValue}

	if r.Likes[key] == nil {
		r.Likes[key] = make(map[int]bool)
	}

	r.Likes[key][userId] = true
	return nil
}

func (r *FakeLikeRepository) RemoveLike(ctx context.Context, userId int, postId int, commentId *int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	commentIdValue := 0
	if commentId != nil {
		commentIdValue = *commentId
	}
	key := likeKey{postID: postId, commentID: commentIdValue}

	if r.Likes[key] == nil {
		return errors.New("like does not exist")
	}

	delete(r.Likes[key], userId)
	return nil
}

func (r *FakeLikeRepository) IsLiked(ctx context.Context, userId int, postId int, commentId *int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	commentIdValue := 0
	if commentId != nil {
		commentIdValue = *commentId
	}
	key := likeKey{postID: postId, commentID: commentIdValue}

	if r.Likes[key] == nil {
		return false, nil
	}

	liked, exists := r.Likes[key][userId]
	return exists && liked, nil
}

// GetPostLikesFromFollowers Updated to match the expected interface signature
func (r *FakeLikeRepository) GetPostLikesFromFollowers(ctx context.Context, postId int, followerId int) ([]queries.GetPostLikesFromFollowersRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	// Only get likes for the post itself (commentID = 0 for post likes)
	key := likeKey{postID: postId, commentID: 0}

	if r.Likes[key] == nil {
		return []queries.GetPostLikesFromFollowersRow{}, nil
	}

	var likes []queries.GetPostLikesFromFollowersRow
	for userID, liked := range r.Likes[key] {
		if liked {
			likes = append(likes, queries.GetPostLikesFromFollowersRow{
				UserID:   userID,
				Username: "user" + strconv.Itoa(userID), // Simple username based on ID
			})
		}
	}

	return likes, nil
}

func (r *FakeLikeRepository) HasLikesFromOthers(ctx context.Context, postId int, userIds []int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	// Only check likes for the post itself (commentID = 0 for post likes)
	key := likeKey{postID: postId, commentID: 0}

	if r.Likes[key] == nil {
		return false, nil
	}

	userIDMap := make(map[int]bool)
	for _, id := range userIds {
		userIDMap[id] = true
	}

	for userID, liked := range r.Likes[key] {
		if liked && !userIDMap[userID] {
			return true, nil
		}
	}

	return false, nil
}

// GetLikesForPost is a helper method for testing that retrieves all likes for a post
func (r *FakeLikeRepository) GetLikesForPost(ctx context.Context, postId int) ([]queries.Like, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	// Only get likes for the post itself (commentID = 0 for post likes)
	key := likeKey{postID: postId, commentID: 0}

	if r.Likes[key] == nil {
		return []queries.Like{}, nil
	}

	var likes []queries.Like
	for userID, liked := range r.Likes[key] {
		if liked {
			likes = append(likes, queries.Like{
				PostID:    postId,
				CommentID: nil,
				UserID:    userID,
			})
		}
	}

	return likes, nil
}
