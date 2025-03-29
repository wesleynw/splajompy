package service

import (
	"context"
	"errors"
	"fmt"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
)

type PostService struct {
	queries *db.Queries
}

func NewPostService(queries *db.Queries) *PostService {
	return &PostService{
		queries: queries,
	}
}

func (s *PostService) GetPostById(ctx context.Context, cUser models.PublicUser, postID int) (*models.DetailedPost, error) {
	post, err := s.queries.GetPostById(ctx, int32(postID))
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	user, err := s.queries.GetUserById(ctx, int32(post.UserID))
	if err != nil {
		return nil, errors.New("unable to find user")
	}

	isLiked, err := s.queries.GetIsLikedByUser(ctx, db.GetIsLikedByUserParams{
		UserID:  cUser.UserID,
		PostID:  post.PostID,
		Column4: true,
	})
	if err != nil {
		return nil, errors.New("unable to find likes")
	}

	images, err := s.queries.GetImagesByPostId(ctx, post.PostID)
	if err != nil {
		return nil, errors.New("unable to find images for post")
	}
	if images == nil {
		images = []db.Image{}
	}

	response := models.DetailedPost{
		Post:    post,
		User:    user,
		IsLiked: isLiked,
		Images:  images,
	}

	return &response, nil
}

func (s *PostService) GetPostsByUserId(ctx context.Context, currentUser models.PublicUser, userID int, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.queries.GetPostsIdsByUserId(ctx, db.GetPostsIdsByUserIdParams{
		UserID: int32(userID),
		Offset: int32(offset),
		Limit:  int32(limit),
	})
	if err != nil {
		return nil, errors.New("unable to find posts")
	}

	posts := []models.DetailedPost{}

	for i := range postIds {
		post, err := s.GetPostById(ctx, currentUser, int(postIds[i]))
		if err != nil {
			return nil, fmt.Errorf("unable to retrieve post %d", postIds[i])
		}
		posts = append(posts, *post)
	}

	return &posts, nil
}

func (s *PostService) AddLikeToPost(ctx context.Context, currentUser models.PublicUser, post_id int) error {
	err := s.queries.AddLike(ctx, db.AddLikeParams{PostID: int32(post_id), UserID: currentUser.UserID, IsPost: true})
	return err
}

func (s *PostService) RemoveLikeFromPost(ctx context.Context, currentUser models.PublicUser, post_id int) error {
	err := s.queries.RemoveLike(ctx, db.RemoveLikeParams{
		PostID: int32(post_id),
		UserID: currentUser.UserID,
		IsPost: true})
	return err
}
