package fakes

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
)

type FakeCommentRepository struct {
	comments       map[int][]queries.Comment
	commentLikes   map[string]bool
	users          map[int]queries.User
	commentCounter int
	mu             sync.Mutex
}

func NewFakeCommentRepository() *FakeCommentRepository {
	return &FakeCommentRepository{
		comments:     make(map[int][]queries.Comment),
		commentLikes: make(map[string]bool),
		users:        make(map[int]queries.User),
		mu:           sync.Mutex{},
	}
}

func (f *FakeCommentRepository) AddCommentToPost(ctx context.Context, userId int, postId int, content string, facets db.Facets) (queries.Comment, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.commentCounter++
	comment := queries.Comment{
		CommentID: f.commentCounter,
		PostID:    postId,
		UserID:    userId,
		Text:      content,
		CreatedAt: pgtype.Timestamp{
			Time:  time.Now(),
			Valid: true,
		},
	}

	if _, exists := f.comments[postId]; !exists {
		f.comments[postId] = []queries.Comment{}
	}

	f.comments[postId] = append(f.comments[postId], comment)
	return comment, nil
}

func (f *FakeCommentRepository) GetCommentById(_ context.Context, commentId int) (queries.Comment, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	for _, comments := range f.comments {
		for _, comment := range comments {
			if comment.CommentID == commentId {
				return comment, nil
			}
		}
	}

	return queries.Comment{}, errors.New("comment not found")
}

func (f *FakeCommentRepository) GetCommentsByPostId(ctx context.Context, postId int) ([]queries.GetCommentsByPostIdRow, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if _, exists := f.comments[postId]; !exists {
		return []queries.GetCommentsByPostIdRow{}, nil
	}

	result := make([]queries.GetCommentsByPostIdRow, 0, len(f.comments[postId]))
	for _, comment := range f.comments[postId] {
		result = append(result, queries.GetCommentsByPostIdRow{
			CommentID: comment.CommentID,
			PostID:    comment.PostID,
			UserID:    comment.UserID,
			Text:      comment.Text,
			CreatedAt: comment.CreatedAt,
		})
	}

	return result, nil
}

func (f *FakeCommentRepository) IsCommentLikedByUser(ctx context.Context, userId int, postId int, commentId int) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	key := f.getLikeKey(userId, postId, commentId)
	liked, exists := f.commentLikes[key]
	if !exists {
		return false, nil
	}

	return liked, nil
}

func (f *FakeCommentRepository) AddLikeToComment(ctx context.Context, userId int, postId int, commentId int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	key := f.getLikeKey(userId, postId, commentId)
	f.commentLikes[key] = true
	return nil
}

func (f *FakeCommentRepository) RemoveLikeFromComment(ctx context.Context, userId int, postId int, commentId int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	key := f.getLikeKey(userId, postId, commentId)
	delete(f.commentLikes, key)
	return nil
}

func (f *FakeCommentRepository) DeleteComment(ctx context.Context, commentId int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	for postId, comments := range f.comments {
		for i, comment := range comments {
			if comment.CommentID == commentId {
				f.comments[postId] = append(comments[:i], comments[i+1:]...)
				return nil
			}
		}
	}

	return errors.New("comment not found")
}

func (f *FakeCommentRepository) GetUserById(ctx context.Context, userId int) (queries.User, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	user, exists := f.users[userId]
	if !exists {
		user = queries.User{
			UserID:    userId,
			Email:     "user-" + string(rune(userId)) + "@example.com",
			Username:  "user-" + string(rune(userId)),
			CreatedAt: pgtype.Timestamp{Time: time.Now(), Valid: true},
			Name:      pgtype.Text{String: "Test User " + string(rune(userId)), Valid: true},
		}
		f.users[userId] = user
	}

	return user, nil
}

func (f *FakeCommentRepository) AddUser(userId int, user queries.User) {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.users[userId] = user
}

func (f *FakeCommentRepository) AddComment(comment queries.Comment) {
	f.mu.Lock()
	defer f.mu.Unlock()

	postId := comment.PostID
	if _, exists := f.comments[postId]; !exists {
		f.comments[postId] = []queries.Comment{}
	}

	f.comments[postId] = append(f.comments[postId], comment)

	if comment.CommentID > f.commentCounter {
		f.commentCounter = comment.CommentID
	}
}

func (f *FakeCommentRepository) ClearComments() {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.comments = make(map[int][]queries.Comment)
	f.commentLikes = make(map[string]bool)
	f.commentCounter = 0
}

func (f *FakeCommentRepository) getLikeKey(userId int, postId int, commentId int) string {
	return string(rune(userId)) + "-" + string(rune(postId)) + "-" + string(rune(commentId))
}
