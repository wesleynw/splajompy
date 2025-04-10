package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/models"
)

type PostService struct {
	queries  *db.Queries
	s3Client *s3.Client
}

func NewPostService(queries *db.Queries, s3Client *s3.Client) *PostService {
	return &PostService{
		queries:  queries,
		s3Client: s3Client,
	}
}

func (s *PostService) NewPost(ctx context.Context, currentUser models.PublicUser, text string, imageBuffer *[]byte, fileType *string, fileExt *string) error {
	post, err := s.queries.InsertPost(ctx, db.InsertPostParams{
		UserID: currentUser.UserID,
		Text:   pgtype.Text{String: text, Valid: true},
	})

	if imageBuffer != nil && fileType != nil && fileExt != nil {
		environment := os.Getenv("ENVIRONMENT")

		s3Key := fmt.Sprintf("%s/posts/%d/%s%s", environment, currentUser.UserID, uuid.New(), *fileExt)

		_, err := s.s3Client.PutObject(ctx, &s3.PutObjectInput{
			Bucket:      aws.String("splajompy-bucket"),
			Key:         &s3Key,
			Body:        bytes.NewReader(*imageBuffer),
			ContentType: aws.String(*fileExt),
			ACL:         types.ObjectCannedACLPublicRead,
		})
		if err != nil {
			log.Printf("error uploading to s3: %v", err)
			return errors.New("error uploading image")
		}

		_, err = s.queries.InsertImage(ctx, db.InsertImageParams{
			PostID:       post.PostID,
			Height:       1000,
			Width:        1000,
			ImageBlobUrl: s3Key,
			DisplayOrder: 0,
		})
		if err != nil {
			return errors.New("unable to insert image")
		}
	}

	return err
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

	commentCount, err := s.queries.GetCommentCountByPostID(ctx, post.PostID)
	if err != nil {
		return nil, errors.New("unable to find comment count for post")
	}

	response := models.DetailedPost{
		Post:         post,
		User:         user,
		IsLiked:      isLiked,
		Images:       images,
		CommentCount: int(commentCount),
	}

	return &response, nil
}

func (s *PostService) GetAllPosts(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.queries.GetAllPostIds(ctx, db.GetAllPostIdsParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		return nil, errors.New("unable to find posts")
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIds)
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

	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetPostsByFollowing(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.queries.GetPostIdsByFollowing(ctx, db.GetPostIdsByFollowingParams{
		UserID: currentUser.UserID,
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		return nil, errors.New("unable to find posts")
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) getPostsByPostIDs(ctx context.Context, currentUser models.PublicUser, postIDs []int32) (*[]models.DetailedPost, error) {
	posts := []models.DetailedPost{}

	for i := range postIDs {
		post, err := s.GetPostById(ctx, currentUser, int(postIDs[i]))
		if err != nil {
			return nil, fmt.Errorf("unable to retrieve post %d", postIDs[i])
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
