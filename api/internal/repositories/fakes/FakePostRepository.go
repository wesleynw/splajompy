package fakes

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
)

type FakePostRepository struct {
	posts        map[int]models.Post
	images       map[int][]queries.Image
	postLikes    map[int]map[int]bool
	commentCount map[int]int
	pollVotes    map[int]map[int]int
	pinnedPosts  map[int]int // userId -> postId
	mutex        sync.RWMutex
	nextPostId   int
	nextImageId  int
}

func NewFakePostRepository() *FakePostRepository {
	var _ repositories.PostRepository = (*FakePostRepository)(nil)

	return &FakePostRepository{
		posts:        make(map[int]models.Post),
		images:       make(map[int][]queries.Image),
		postLikes:    make(map[int]map[int]bool),
		commentCount: make(map[int]int),
		pollVotes:    make(map[int]map[int]int),
		pinnedPosts:  make(map[int]int),
		nextPostId:   1,
		nextImageId:  1,
	}
}

func (r *FakePostRepository) InsertPost(ctx context.Context, userId int, content string, facets db.Facets, attributes *db.Attributes, visibilityType *models.VisibilityTypeEnum) (*models.Post, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	postId := r.nextPostId
	r.nextPostId++

	now := time.Now()
	post := models.Post{
		PostID:     postId,
		UserID:     userId,
		Text:       content,
		Facets:     facets,
		Attributes: attributes,
		Visibility: visibilityType,
		CreatedAt:  now,
	}

	r.posts[postId] = post
	r.postLikes[postId] = make(map[int]bool)
	r.images[postId] = make([]queries.Image, 0)
	r.pollVotes[postId] = make(map[int]int)

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

func (r *FakePostRepository) GetPostById(ctx context.Context, postId int, currentUserId int) (*models.Post, error) {
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

	// Iterate through all posts to find ones by this user
	for _, post := range r.posts {
		if post.UserID == userId {
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
		PostID:       id,
		Height:       height,
		Width:        width,
		ImageBlobUrl: url,
		DisplayOrder: displayOrder,
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

	return r.commentCount[id], nil
}

func (r *FakePostRepository) SetCommentCount(postId int, count int) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.commentCount[postId] = count
}

func (r *FakePostRepository) GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var userPostIds []int
	for id, post := range r.posts {
		if post.UserID == userId {
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

func (r *FakePostRepository) getPaginatedIds(ids []int, limit int, offset int) ([]int, error) {
	if offset >= len(ids) {
		return []int{}, nil
	}

	end := min(offset+limit, len(ids))

	return ids[offset:end], nil
}

func (r *FakePostRepository) GetPollVotesGrouped(ctx context.Context, postId int) ([]queries.GetPollVotesGroupedRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if _, exists := r.posts[postId]; !exists {
		return []queries.GetPollVotesGroupedRow{}, errors.New("post not found")
	}

	votes := r.pollVotes[postId]
	optionCounts := make(map[int]int64)

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
		return new(optionIndex), nil
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
		r.pollVotes[postId] = make(map[int]int)
	}

	r.pollVotes[postId][userId] = optionIndex
	return nil
}

func (r *FakePostRepository) SetPollVote(userId int, postId int, optionIndex int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if _, exists := r.posts[postId]; !exists {
		return errors.New("post not found")
	}

	if r.pollVotes[postId] == nil {
		r.pollVotes[postId] = make(map[int]int)
	}

	r.pollVotes[postId][userId] = optionIndex
	return nil
}

// GetAllPostIdsCursor retrieves post IDs using cursor-based pagination
func (r *FakePostRepository) GetAllPostIdsCursor(ctx context.Context, limit int, beforeTimestamp *time.Time, currentUserId int) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	// Convert map to slice for sorting
	type postWithId struct {
		id   int
		post *models.Post
	}
	var posts []postWithId
	for id, post := range r.posts {
		if beforeTimestamp == nil || post.CreatedAt.Before(*beforeTimestamp) {
			posts = append(posts, postWithId{id: id, post: &post})
		}
	}

	// Sort by CreatedAt DESC to match database behavior
	sort.Slice(posts, func(i, j int) bool {
		return posts[i].post.CreatedAt.After(posts[j].post.CreatedAt)
	})

	// Extract IDs and apply limit
	var filteredIds []int
	for i, post := range posts {
		if i >= limit {
			break
		}
		filteredIds = append(filteredIds, post.id)
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
				PostID:           post.PostID,
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
func (r *FakePostRepository) GetPostIdsByUserIdCursor(ctx context.Context, userId int, targetUserId int, limit int, beforeTimestamp *time.Time) ([]int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var filteredIds []int
	for id, post := range r.posts {
		if post.UserID == userId && (beforeTimestamp == nil || post.CreatedAt.Before(*beforeTimestamp)) {
			filteredIds = append(filteredIds, id)
		}
	}

	if len(filteredIds) > limit {
		filteredIds = filteredIds[:limit]
	}
	return filteredIds, nil
}

// PinPost pins a post for a user
func (r *FakePostRepository) PinPost(ctx context.Context, userId int, postId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	// Check if post exists
	if _, exists := r.posts[postId]; !exists {
		return errors.New("post not found")
	}

	// Check if user owns the post
	post := r.posts[postId]
	if post.UserID != userId {
		return errors.New("can only pin your own posts")
	}

	r.pinnedPosts[userId] = postId
	return nil
}

// UnpinPost unpins the currently pinned post for a user
func (r *FakePostRepository) UnpinPost(ctx context.Context, userId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	delete(r.pinnedPosts, userId)
	return nil
}

// GetPinnedPostId retrieves the pinned post ID for a user
func (r *FakePostRepository) GetPinnedPostId(ctx context.Context, userId int) (*int, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if postId, exists := r.pinnedPosts[userId]; exists {
		return &postId, nil
	}
	return nil, nil
}
