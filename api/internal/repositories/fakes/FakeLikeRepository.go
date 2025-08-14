package fakes

import (
	"context"
	"errors"
	"sync"

	"splajompy.com/api/v2/internal/db/queries"
)

type FakeLikeRepository struct {
	Likes map[int32]map[int32]bool // postID -> userID -> liked
	mutex sync.RWMutex
}

func NewFakeLikeRepository() *FakeLikeRepository {
	return &FakeLikeRepository{
		Likes: make(map[int32]map[int32]bool),
	}
}

func (r *FakeLikeRepository) AddLike(_ context.Context, userId int, postId int, _ bool) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	postID := int32(postId)
	userID := int32(userId)

	if r.Likes[postID] == nil {
		r.Likes[postID] = make(map[int32]bool)
	}

	r.Likes[postID][userID] = true
	return nil
}

func (r *FakeLikeRepository) RemoveLike(ctx context.Context, userId int, postId int, isPost bool) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	postID := int32(postId)
	userID := int32(userId)

	if r.Likes[postID] == nil {
		return errors.New("like does not exist")
	}

	delete(r.Likes[postID], userID)
	return nil
}

// Updated to match the expected interface signature
func (r *FakeLikeRepository) GetPostLikesFromFollowers(ctx context.Context, postId int, followerId int) ([]queries.GetPostLikesFromFollowersRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	postID := int32(postId)

	if r.Likes[postID] == nil {
		return []queries.GetPostLikesFromFollowersRow{}, nil
	}

	var likes []queries.GetPostLikesFromFollowersRow
	for userID, liked := range r.Likes[postID] {
		if liked {
			likes = append(likes, queries.GetPostLikesFromFollowersRow{
				UserID:   userID,
				Username: "user" + string(userID+48), // Simple username based on ID
			})
		}
	}

	return likes, nil
}

func (r *FakeLikeRepository) HasLikesFromOthers(ctx context.Context, postId int, userIds []int32) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	postID := int32(postId)

	if r.Likes[postID] == nil {
		return false, nil
	}

	// Create a map for quick lookup
	userIDMap := make(map[int32]bool)
	for _, id := range userIds {
		userIDMap[id] = true
	}

	for userID, liked := range r.Likes[postID] {
		if liked && !userIDMap[userID] {
			return true, nil
		}
	}

	return false, nil
}

func (r *FakeLikeRepository) GetLikesForPost(ctx context.Context, postId int) ([]queries.Like, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	postID := int32(postId)

	if r.Likes[postID] == nil {
		return []queries.Like{}, nil
	}

	var likes []queries.Like
	for userID, liked := range r.Likes[postID] {
		if liked {
			likes = append(likes, queries.Like{
				UserID: userID,
			})
		}
	}

	return likes, nil
}
