package fakes

import (
	"context"
	"errors"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"sync"
	"time"
)

type FakePostRepository struct {
	posts        map[int]models.Post
	images       map[int][]queries.Image
	postLikes    map[int]map[int]bool
	commentCount map[int]int
	pollVotes    map[int]map[int]int32
	mutex        sync.RWMutex
	nextPostId   int
	nextImageId  int32
}

func NewFakePostRepository() *FakePostRepository {
	var _ repositories.PostRepository = (*FakePostRepository)(nil)

	return &FakePostRepository{
		posts:        make(map[int]models.Post),
		images:       make(map[int][]queries.Image),
		postLikes:    make(map[int]map[int]bool),
		commentCount: make(map[int]int),
		pollVotes:    make(map[int]map[int]int32),
		nextPostId:   1,
		nextImageId:  1,
	}
}

func (r *FakePostRepository) InsertPost(ctx context.Context, userId int, content string, facets db.Facets, attributes *db.Attributes) (*models.Post, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	postId := r.nextPostId
	r.nextPostId++

	now := time.Now()
	post := models.Post{
		PostID:     postId,
		UserID:     int32(userId),
		Text:       content,
		Facets:     facets,
		Attributes: attributes,
		CreatedAt:  now,
	}

	r.posts[postId] = post
	r.postLikes[postId] = make(map[int]bool)
	r.images[postId] = make([]queries.Image, 0)
	r.pollVotes[postId] = make(map[int]int32)

	return &post, nil
}

func (r *FakePostRepository) DeletePost(ctx context.Context, postId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := postId
	if _, exists := r.posts[id]; !exists {
		return errors.New("post not found")
	}

	delete(r.posts, id)
	delete(r.images, id)
	delete(r.postLikes, id)
	delete(r.commentCount, id)
	delete(r.pollVotes, id)

	return nil
}

func (r *FakePostRepository) GetPostById(ctx context.Context, postId int) (*models.Post, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := postId
	post, exists := r.posts[id]
	if !exists {
		return nil, errors.New("post not found")
	}

	return &post, nil
}

func (r *FakePostRepository) IsPostLikedByUserId(_ context.Context, userId int, postId int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	postLikes, exists := r.postLikes[postId]
	if !exists {
		return false, errors.New("post not found")
	}

	return postLikes[userId], nil
}

func (r *FakePostRepository) GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := postId
	if _, exists := r.posts[id]; !exists {
		return []queries.Image{}, nil
	}

	images := r.images[id]
	return images, nil
}

func (r *FakePostRepository) GetAllImagesForUser(ctx context.Context, userId int) ([]queries.Image, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var allImages []queries.Image
	userIdInt32 := int32(userId)

	// Iterate through all posts to find ones by this user
	for _, post := range r.posts {
		if post.UserID == userIdInt32 {
			// Get images for this post
			if images, exists := r.images[post.PostID]; exists {
				allImages = append(allImages, images...)
			}
		}
	}

	return allImages, nil
}

func (r *FakePostRepository) InsertImage(ctx context.Context, postId int, height int, width int, url string, displayOrder int) (queries.Image, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := postId
	if _, exists := r.posts[id]; !exists {
		return queries.Image{}, errors.New("post not found")
	}

	imageId := r.nextImageId
	r.nextImageId++

	image := queries.Image{
		ImageID:      imageId,
		PostID:       int32(id),
		Height:       int32(height),
		Width:        int32(width),
		ImageBlobUrl: url,
		DisplayOrder: int32(displayOrder),
	}

	r.images[id] = append(r.images[id], image)

	return image, nil
}

func (r *FakePostRepository) GetCommentCountForPost(ctx context.Context, postId int) (int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := postId
	if _, exists := r.posts[id]; !exists {
		return 0, errors.New("post not found")
	}

	return int(r.commentCount[id]), nil
}

func (r *FakePostRepository) SetCommentCount(postId int, count int) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.commentCount[postId] = count
}

func (r *FakePostRepository) GetAllPostIds(ctx context.Context, limit int, offset int, currentUserId int) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	return r.getPaginatedIds(r.getAllPostIds(), limit, offset)
}

func (r *FakePostRepository) GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	// In a real implementation, this would filter posts based on followed users
	// For simplicity, we'll just return all post IDs
	return r.GetAllPostIds(ctx, limit, offset, userId)
}

func (r *FakePostRepository) GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var userPostIds []int
	for id, post := range r.posts {
		if int(post.UserID) == userId {
			userPostIds = append(userPostIds, id)
		}
	}

	return r.getPaginatedIds(userPostIds, limit, offset)
}

func (r *FakePostRepository) SetLike(userId int, postId int, liked bool) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := postId
	if _, exists := r.posts[id]; !exists {
		return errors.New("post not found")
	}

	if r.postLikes[id] == nil {
		r.postLikes[id] = make(map[int]bool)
	}

	r.postLikes[id][userId] = liked
	return nil
}

func (r *FakePostRepository) getAllPostIds() []int {
	ids := make([]int, 0, len(r.posts))
	for id := range r.posts {
		ids = append(ids, id)
	}
	return ids
}

func (r *FakePostRepository) getPaginatedIds(ids []int, limit int, offset int) ([]int, error) {
	if offset >= len(ids) {
		return []int{}, nil
	}

	end := offset + limit
	if end > len(ids) {
		end = len(ids)
	}

	return ids[offset:end], nil
}

func (r *FakePostRepository) GetPostIdsForMutualFeed(ctx context.Context, userId int, limit int, offset int) ([]queries.GetPostIdsForMutualFeedRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var rows []queries.GetPostIdsForMutualFeedRow
	for _, post := range r.posts {
		row := queries.GetPostIdsForMutualFeedRow{
			PostID:           int32(post.PostID),
			UserID:           post.UserID,
			RelationshipType: "friend",
			MutualUsernames:  nil,
		}
		rows = append(rows, row)
	}

	// Apply pagination
	start := offset
	if start >= len(rows) {
		return []queries.GetPostIdsForMutualFeedRow{}, nil
	}

	end := start + limit
	if end > len(rows) {
		end = len(rows)
	}

	return rows[start:end], nil
}

func (r *FakePostRepository) GetPollVotesGrouped(ctx context.Context, postId int) ([]queries.GetPollVotesGroupedRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if _, exists := r.posts[postId]; !exists {
		return []queries.GetPollVotesGroupedRow{}, errors.New("post not found")
	}

	votes := r.pollVotes[postId]
	optionCounts := make(map[int32]int64)

	for _, optionIndex := range votes {
		optionCounts[optionIndex]++
	}

	var result []queries.GetPollVotesGroupedRow
	for optionIndex, count := range optionCounts {
		result = append(result, queries.GetPollVotesGroupedRow{
			OptionIndex: optionIndex,
			Count:       count,
		})
	}

	return result, nil
}

func (r *FakePostRepository) GetUserVoteInPoll(ctx context.Context, postId int, userId int) (*int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if _, exists := r.posts[postId]; !exists {
		return nil, errors.New("post not found")
	}

	votes := r.pollVotes[postId]
	if optionIndex, exists := votes[userId]; exists {
		result := int(optionIndex)
		return &result, nil
	}

	return nil, nil
}

func (r *FakePostRepository) InsertVote(ctx context.Context, postId int, userId int, optionIndex int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if _, exists := r.posts[postId]; !exists {
		return errors.New("post not found")
	}

	if r.pollVotes[postId] == nil {
		r.pollVotes[postId] = make(map[int]int32)
	}

	r.pollVotes[postId][userId] = int32(optionIndex)
	return nil
}

func (r *FakePostRepository) SetPollVote(userId int, postId int, optionIndex int32) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if _, exists := r.posts[postId]; !exists {
		return errors.New("post not found")
	}

	if r.pollVotes[postId] == nil {
		r.pollVotes[postId] = make(map[int]int32)
	}

	r.pollVotes[postId][userId] = optionIndex
	return nil
}

// GetAllPostIdsCursor retrieves post IDs using cursor-based pagination
func (r *FakePostRepository) GetAllPostIdsCursor(ctx context.Context, limit int, beforeTimestamp *time.Time, currentUserId int) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var filteredIds []int
	for id, post := range r.posts {
		if beforeTimestamp == nil || post.CreatedAt.Before(*beforeTimestamp) {
			filteredIds = append(filteredIds, id)
		}
	}

	if len(filteredIds) > limit {
		filteredIds = filteredIds[:limit]
	}
	return filteredIds, nil
}

// GetPostIdsForFollowingCursor retrieves post IDs from followed users using cursor-based pagination
func (r *FakePostRepository) GetPostIdsForFollowingCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]int, error) {
	// For simplicity, this fake implementation returns the same as GetAllPostIdsCursor
	return r.GetAllPostIdsCursor(ctx, limit, beforeTimestamp, userId)
}

// GetPostIdsForMutualFeedCursor retrieves post IDs for mutual feed using cursor-based pagination
func (r *FakePostRepository) GetPostIdsForMutualFeedCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]queries.GetPostIdsForMutualFeedCursorRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var rows []queries.GetPostIdsForMutualFeedCursorRow
	for _, post := range r.posts {
		if beforeTimestamp == nil || post.CreatedAt.Before(*beforeTimestamp) {
			row := queries.GetPostIdsForMutualFeedCursorRow{
				PostID:           int32(post.PostID),
				UserID:           post.UserID,
				RelationshipType: "friend",
				MutualUsernames:  nil,
			}
			rows = append(rows, row)
		}
	}

	if len(rows) > limit {
		rows = rows[:limit]
	}
	return rows, nil
}

// GetPostIdsByUserIdCursor retrieves post IDs for a specific user using cursor-based pagination
func (r *FakePostRepository) GetPostIdsByUserIdCursor(ctx context.Context, userId int, limit int, beforeTimestamp *time.Time) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var filteredIds []int
	for id, post := range r.posts {
		if int(post.UserID) == userId && (beforeTimestamp == nil || post.CreatedAt.Before(*beforeTimestamp)) {
			filteredIds = append(filteredIds, id)
		}
	}

	if len(filteredIds) > limit {
		filteredIds = filteredIds[:limit]
	}
	return filteredIds, nil
}
