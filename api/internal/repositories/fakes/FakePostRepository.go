package fakes

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"sync"
	"time"
)

type FakePostRepository struct {
	posts        map[int32]queries.Post
	images       map[int32][]queries.Image
	postLikes    map[int32]map[int32]bool
	commentCount map[int32]int32
	mutex        sync.RWMutex
	nextPostId   int32
	nextImageId  int32
}

func NewFakePostRepository() *FakePostRepository {
	return &FakePostRepository{
		posts:        make(map[int32]queries.Post),
		images:       make(map[int32][]queries.Image),
		postLikes:    make(map[int32]map[int32]bool),
		commentCount: make(map[int32]int32),
		nextPostId:   1,
		nextImageId:  1,
	}
}

func (r *FakePostRepository) InsertPost(ctx context.Context, userId int, content string, facets db.Facets) (queries.Post, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	postId := r.nextPostId
	r.nextPostId++

	now := time.Now()
	post := queries.Post{
		PostID:    postId,
		UserID:    int32(userId),
		Text:      pgtype.Text{String: content, Valid: true},
		Facets:    facets,
		CreatedAt: pgtype.Timestamp{Time: now, Valid: true},
	}

	r.posts[postId] = post
	r.postLikes[postId] = make(map[int32]bool)
	r.images[postId] = make([]queries.Image, 0)

	return post, nil
}

func (r *FakePostRepository) DeletePost(ctx context.Context, postId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := int32(postId)
	if _, exists := r.posts[id]; !exists {
		return errors.New("post not found")
	}

	delete(r.posts, id)
	delete(r.images, id)
	delete(r.postLikes, id)
	delete(r.commentCount, id)

	return nil
}

func (r *FakePostRepository) GetPostById(ctx context.Context, postId int) (queries.Post, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := int32(postId)
	post, exists := r.posts[id]
	if !exists {
		return queries.Post{}, errors.New("post not found")
	}

	return post, nil
}

func (r *FakePostRepository) IsPostLikedByUserId(_ context.Context, userId int, postId int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	postLikes, exists := r.postLikes[int32(postId)]
	if !exists {
		return false, errors.New("post not found")
	}

	return postLikes[int32(userId)], nil
}

func (r *FakePostRepository) GetImagesForPost(ctx context.Context, postId int) ([]queries.Image, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := int32(postId)
	if _, exists := r.posts[id]; !exists {
		return nil, errors.New("post not found")
	}

	images := r.images[id]
	return images, nil
}

func (r *FakePostRepository) InsertImage(ctx context.Context, postId int, height int, width int, url string, displayOrder int) (queries.Image, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := int32(postId)
	if _, exists := r.posts[id]; !exists {
		return queries.Image{}, errors.New("post not found")
	}

	imageId := r.nextImageId
	r.nextImageId++

	image := queries.Image{
		ImageID:      imageId,
		PostID:       id,
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

	id := int32(postId)
	if _, exists := r.posts[id]; !exists {
		return 0, errors.New("post not found")
	}

	return int(r.commentCount[id]), nil
}

func (r *FakePostRepository) SetCommentCount(postId int, count int) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.commentCount[int32(postId)] = int32(count)
}

func (r *FakePostRepository) GetAllPostIds(ctx context.Context, limit int, offset int) ([]int32, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	return r.getPaginatedIds(r.getAllPostIds(), limit, offset)
}

func (r *FakePostRepository) GetPostIdsForFollowing(ctx context.Context, userId int, limit int, offset int) ([]int32, error) {
	// In a real implementation, this would filter posts based on followed users
	// For simplicity, we'll just return all post IDs
	return r.GetAllPostIds(ctx, limit, offset)
}

func (r *FakePostRepository) GetPostIdsForUser(ctx context.Context, userId int, limit int, offset int) ([]int32, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var userPostIds []int32
	for id, post := range r.posts {
		if post.UserID == int32(userId) {
			userPostIds = append(userPostIds, id)
		}
	}

	return r.getPaginatedIds(userPostIds, limit, offset)
}

func (r *FakePostRepository) SetLike(userId int, postId int, liked bool) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := int32(postId)
	if _, exists := r.posts[id]; !exists {
		return errors.New("post not found")
	}

	if r.postLikes[id] == nil {
		r.postLikes[id] = make(map[int32]bool)
	}

	r.postLikes[id][int32(userId)] = liked
	return nil
}

func (r *FakePostRepository) getAllPostIds() []int32 {
	ids := make([]int32, 0, len(r.posts))
	for id := range r.posts {
		ids = append(ids, id)
	}
	return ids
}

func (r *FakePostRepository) getPaginatedIds(ids []int32, limit int, offset int) ([]int32, error) {
	if offset >= len(ids) {
		return []int32{}, nil
	}

	end := offset + limit
	if end > len(ids) {
		end = len(ids)
	}

	return ids[offset:end], nil
}
