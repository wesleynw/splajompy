package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	"log"
	"math"
	"os"
	"regexp"
	"sort"
	db2 "splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/generated"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/models"
)

type PostService struct {
	querier  db.Querier
	s3Client *s3.Client
}

func NewPostService(querier db.Querier, s3Client *s3.Client) *PostService {
	return &PostService{
		querier:  querier,
		s3Client: s3Client,
	}
}

func (s *PostService) NewPost(ctx context.Context, currentUser models.PublicUser, text string, imageKeymap map[int]string) error {
	facets, err := generateFacets(ctx, s.querier, text)
	if err != nil {
		return err
	}

	post, err := s.querier.InsertPost(ctx, db.InsertPostParams{
		UserID: currentUser.UserID,
		Text:   pgtype.Text{String: text, Valid: true},
		Facets: facets,
	})
	if err != nil {
		return errors.New("unable to create post")
	}

	environment := os.Getenv("ENVIRONMENT")

	for displayOrder, s3key := range imageKeymap {
		filename := (s3key)[strings.LastIndex(s3key, "/"):]
		newKey := fmt.Sprintf("%s/posts/%d/%d%s", environment, currentUser.UserID, post.PostID, filename)

		_, err := s.s3Client.CopyObject(ctx, &s3.CopyObjectInput{
			Bucket:     aws.String("splajompy-bucket"),
			CopySource: aws.String("splajompy-bucket/" + s3key),
			Key:        aws.String(newKey),
			ACL:        types.ObjectCannedACLPublicRead,
		})
		if err != nil {
			print("error: ", err)
			return errors.New("unable to create post")
		}

		_, err = s.s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
			Bucket: aws.String("splajompy-bucket"),
			Key:    &s3key,
		})
		if err != nil {
			return errors.New("unable to create post")
		}

		_, err = s.querier.InsertImage(ctx, db.InsertImageParams{
			PostID:       post.PostID,
			Height:       500,
			Width:        500,
			ImageBlobUrl: newKey,
			DisplayOrder: int32(displayOrder),
		})
		if err != nil {
			return errors.New("unable to create post")
		}
	}

	return nil
}

func (s *PostService) NewPresignedStagingUrl(ctx context.Context, currentUser models.PublicUser, extension *string, folder *string) (string, string, error) {
	environment := os.Getenv("ENVIRONMENT")
	presignClient := s3.NewPresignClient(s.s3Client)

	s3Key := fmt.Sprintf("%s/posts/staging/%d/%s/%s.%s", environment, currentUser.UserID, *folder, uuid.New(), *extension)

	req, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String("splajompy-bucket"),
		Key:         aws.String(s3Key),
		ContentType: extension,
		ACL:         types.ObjectCannedACLPublicRead,
	}, func(opts *s3.PresignOptions) {
		opts.Expires = time.Minute * 5
	})
	if err != nil {
		log.Printf("Couldn't get a presigned request to put. Here's why: %v\n", err)
	}

	return s3Key, req.URL, nil
}

func (s *PostService) GetPostById(ctx context.Context, cUser models.PublicUser, postID int) (*models.DetailedPost, error) {
	post, err := s.querier.GetPostById(ctx, int32(postID))
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	user, err := s.querier.GetUserById(ctx, post.UserID)
	if err != nil {
		return nil, errors.New("unable to find user")
	}

	isLiked, err := s.querier.GetIsLikedByUser(ctx, db.GetIsLikedByUserParams{
		UserID:  cUser.UserID,
		PostID:  post.PostID,
		Column4: true,
	})
	if err != nil {
		return nil, errors.New("unable to find likes")
	}

	images, err := s.querier.GetImagesByPostId(ctx, post.PostID)
	if err != nil {
		return nil, errors.New("unable to find images for post")
	}
	if images == nil {
		images = []db.Image{}
	}

	for i := range images {
		images[i].ImageBlobUrl = "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/" + images[i].ImageBlobUrl
	}

	commentCount, err := s.querier.GetCommentCountByPostID(ctx, post.PostID)
	if err != nil {
		return nil, errors.New("unable to find comment count for post")
	}

	relevantLikes, hasOtherLikes, err := getRelevantLikes(ctx, s.querier, cUser, postID)
	if err != nil {
		return nil, errors.New("unable to find relevant likes")
	}

	response := models.DetailedPost{
		Post:          post,
		User:          user,
		IsLiked:       isLiked,
		Images:        images,
		CommentCount:  int(commentCount),
		RelevantLikes: relevantLikes,
		HasOtherLikes: hasOtherLikes,
	}

	return &response, nil
}

func (s *PostService) GetAllPosts(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.querier.GetAllPostIds(ctx, db.GetAllPostIdsParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		return nil, errors.New("unable to find posts")
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetPostsByUserId(ctx context.Context, currentUser models.PublicUser, userID int, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.querier.GetPostsIdsByUserId(ctx, db.GetPostsIdsByUserIdParams{
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
	postIds, err := s.querier.GetPostIdsByFollowing(ctx, db.GetPostIdsByFollowingParams{
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
	var posts = make([]models.DetailedPost, 0)

	for i := range postIDs {
		post, err := s.GetPostById(ctx, currentUser, int(postIDs[i]))
		if err != nil {
			return nil, fmt.Errorf("unable to retrieve post %d", postIDs[i])
		}
		posts = append(posts, *post)
	}

	return &posts, nil
}

func (s *PostService) AddLikeToPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.querier.AddLike(ctx, db.AddLikeParams{PostID: int32(postId), UserID: currentUser.UserID, IsPost: true})
	if err != nil {
		return err
	}

	post, err := s.querier.GetPostById(ctx, int32(postId))
	if err != nil {
		return err
	}

	err = s.querier.InsertNotification(ctx, db.InsertNotificationParams{
		UserID:  post.UserID,
		PostID:  pgtype.Int4{Int32: int32(postId), Valid: true},
		Message: fmt.Sprintf("%s liked your post.", currentUser.Username),
	})

	return err
}

func (s *PostService) RemoveLikeFromPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.querier.RemoveLike(ctx, db.RemoveLikeParams{
		PostID: int32(postId),
		UserID: currentUser.UserID,
		IsPost: true})
	return err
}

func (s *PostService) DeletePost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	post, err := s.querier.GetPostById(ctx, int32(postId))
	if err != nil {
		return err
	}

	if post.UserID != currentUser.UserID {
		return errors.New("unable to delete post")
	}

	return s.querier.DeletePost(ctx, int32(postId))
}

func generateFacets(ctx context.Context, s db.Querier, text string) ([]db2.Facet, error) {
	re := regexp.MustCompile(`@(\w+)`)
	matches := re.FindAllStringSubmatchIndex(text, -1)

	var facets []db2.Facet

	for _, match := range matches {
		start, end := match[0], match[1]
		username := text[start+1 : end]
		user, err := s.GetUserByUsername(ctx, username)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return nil, err
		}
		facets = append(facets, db2.Facet{
			Type:       "mention",
			UserId:     int(user.UserID),
			IndexStart: start,
			IndexEnd:   end,
		})
	}

	return facets, nil
}

func getRelevantLikes(ctx context.Context, s db.Querier, currentUser models.PublicUser, postId int) ([]models.RelevantLike, bool, error) {
	likes, err := s.GetPostLikesFromFollowers(ctx, db.GetPostLikesFromFollowersParams{
		PostID:     int32(postId),
		FollowerID: currentUser.UserID,
	})
	if err != nil {
		return nil, false, err
	}

	sort.SliceStable(likes, func(i, j int) bool {
		return seededRandom(postId+int(likes[i].UserID)) < seededRandom(postId+int(likes[i].UserID))
	})

	count := min(len(likes), 2)

	mappedLikes := make([]models.RelevantLike, count)
	userIDs := make([]int32, count)
	for i, like := range likes[:count] {
		mappedLikes[i] = models.RelevantLike{
			Username: like.Username,
			UserID:   like.UserID,
		}
		userIDs[i] = like.UserID
	}

	hasOtherLikes, err := s.HasLikesFromOthers(ctx, db.HasLikesFromOthersParams{
		PostID:  int32(postId),
		Column2: userIDs,
	})
	if err != nil {
		return nil, false, err
	}

	return mappedLikes, hasOtherLikes, nil
}

func seededRandom(seed int) float64 {
	var x = math.Sin(float64(seed)) * 1000
	return x - math.Floor(x)
}
