package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/resend/resend-go/v2"
	"math"
	"os"
	"sort"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/templates"
	"splajompy.com/api/v2/internal/utilities"
)

type PostService struct {
	postRepository         repositories.PostRepository
	userRepository         repositories.UserRepository
	likeRepository         repositories.LikeRepository
	notificationRepository repositories.NotificationRepository
	bucketRepository       repositories.BucketRepository
	emailService           *resend.Client
}

func NewPostService(postRepository repositories.PostRepository, userRepository repositories.UserRepository, likeRepository repositories.LikeRepository, notificationRepository repositories.NotificationRepository, bucketRepo repositories.BucketRepository, emailService *resend.Client) *PostService {
	return &PostService{
		postRepository:         postRepository,
		userRepository:         userRepository,
		likeRepository:         likeRepository,
		notificationRepository: notificationRepository,
		bucketRepository:       bucketRepo,
		emailService:           emailService,
	}
}

func (s *PostService) NewPost(ctx context.Context, currentUser models.PublicUser, text string, imageKeymap map[int]string) error {
	facets, err := utilities.GenerateFacets(ctx, s.userRepository, text)
	if err != nil {
		return err
	}

	post, err := s.postRepository.InsertPost(ctx, int(currentUser.UserID), text, facets)
	if err != nil {
		return errors.New("unable to create post")
	}

	environment := os.Getenv("ENVIRONMENT")

	for displayOrder, s3key := range imageKeymap {
		destinationKey := repositories.GetDestinationKey(
			environment,
			currentUser.UserID,
			post.PostID,
			s3key,
		)

		err := s.bucketRepository.CopyObject(ctx, s3key, destinationKey)
		if err != nil {
			return errors.New("unable to create post")
		}

		err = s.bucketRepository.DeleteObject(ctx, s3key)
		if err != nil {
			return errors.New("unable to create post")
		}

		_, err = s.postRepository.InsertImage(ctx, int(post.PostID), 500, 500, destinationKey, int(int32(displayOrder)))
		if err != nil {
			return errors.New("unable to create post")
		}
	}

	return nil
}

func (s *PostService) NewPresignedStagingUrl(ctx context.Context, currentUser models.PublicUser, extension *string, folder *string) (string, string, error) {
	return s.bucketRepository.GeneratePresignedURL(ctx, currentUser.UserID, extension, folder)
}

func (s *PostService) GetPostById(ctx context.Context, cUser models.PublicUser, postID int) (*models.DetailedPost, error) {
	post, err := s.postRepository.GetPostById(ctx, postID)
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	user, err := s.userRepository.GetUserById(ctx, int(post.UserID))
	if err != nil {
		return nil, errors.New("unable to find user")
	}

	isLiked, err := s.postRepository.IsPostLikedByUserId(ctx,
		int(cUser.UserID),
		int(post.PostID),
	)
	if err != nil {
		return nil, errors.New("unable to find likes")
	}

	images, err := s.postRepository.GetImagesForPost(ctx, int(post.PostID))
	if err != nil {
		return nil, errors.New("unable to find images for post")
	}
	if images == nil {
		images = []queries.Image{}
	}

	for i := range images {
		images[i].ImageBlobUrl = s.bucketRepository.GetObjectURL(images[i].ImageBlobUrl)
	}

	commentCount, err := s.postRepository.GetCommentCountForPost(ctx, int(post.PostID))
	if err != nil {
		return nil, errors.New("unable to find comment count for post")
	}

	relevantLikes, hasOtherLikes, err := s.getRelevantLikes(ctx, cUser, postID)
	if err != nil {
		return nil, errors.New("unable to find relevant likes")
	}

	response := models.DetailedPost{
		Post:          post,
		User:          user,
		IsLiked:       isLiked,
		Images:        images,
		CommentCount:  commentCount,
		RelevantLikes: relevantLikes,
		HasOtherLikes: hasOtherLikes,
	}

	return &response, nil
}

func (s *PostService) GetAllPosts(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.postRepository.GetAllPostIds(ctx, limit, offset)
	if err != nil {
		return nil, errors.New("unable to find posts")
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetPostsByUserId(ctx context.Context, currentUser models.PublicUser, userID int, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.postRepository.GetPostIdsForUser(ctx, userID, limit, offset)
	if err != nil {
		return nil, errors.New("unable to find posts")
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetPostsByFollowing(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.postRepository.GetPostIdsForFollowing(ctx, int(currentUser.UserID),
		limit, offset)
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
	err := s.likeRepository.AddLike(ctx, int(currentUser.UserID), postId, true)
	if err != nil {
		return err
	}

	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	text := fmt.Sprintf("@%s liked your post", currentUser.Username)
	facets, err := utilities.GenerateFacets(ctx, s.userRepository, text)
	if err != nil {
		return err
	}
	err = s.notificationRepository.InsertNotification(ctx, int(post.UserID), &postId, nil, &facets, text)

	return err
}

func (s *PostService) RemoveLikeFromPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.likeRepository.RemoveLike(ctx, int(currentUser.UserID), postId, true)
	return err
}

func (s *PostService) DeletePost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	if post.UserID != currentUser.UserID {
		return errors.New("unable to delete post")
	}

	return s.postRepository.DeletePost(ctx, postId)
}

func (s *PostService) getRelevantLikes(ctx context.Context, currentUser models.PublicUser, postId int) ([]models.RelevantLike, bool, error) {
	likes, err := s.likeRepository.GetPostLikesFromFollowers(ctx, postId, int(currentUser.UserID))
	if err != nil {
		return nil, false, err
	}

	sort.SliceStable(likes, func(i, j int) bool {
		return seededRandom(postId+int(likes[i].UserID)) < seededRandom(postId+int(likes[i].UserID))
	})

	count := min(len(likes), 2)

	mappedLikes := make([]models.RelevantLike, count)
	userIDs := make([]int32, count+1)
	for i, like := range likes[:count] {
		mappedLikes[i] = models.RelevantLike{
			Username: like.Username,
			UserID:   like.UserID,
		}
		userIDs[i] = like.UserID
	}

	// don't include the current user
	userIDs[count] = currentUser.UserID

	hasOtherLikes, err := s.likeRepository.HasLikesFromOthers(ctx, postId, userIDs)
	if err != nil {
		return nil, false, err
	}

	return mappedLikes, hasOtherLikes, nil
}

func (s *PostService) ReportPost(ctx context.Context, currentUser *models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	images, err := s.postRepository.GetImagesForPost(ctx, int(post.PostID))
	if err != nil {
		return err
	}
	if images == nil {
		images = []queries.Image{}
	}

	for i := range images {
		images[i].ImageBlobUrl = s.bucketRepository.GetObjectURL(images[i].ImageBlobUrl)
	}

	html, err := templates.GeneratePostReportEmail(currentUser.Username, post, images)
	if err != nil {
		return err
	}

	params := &resend.SendEmailRequest{
		From:    "Splajompy <no-reply@splajompy.com>",
		To:      []string{"wesleynw@pm.me"},
		Subject: fmt.Sprintf("@%s reported a post", currentUser.Username),
		Html:    html,
	}

	_, err = s.emailService.Emails.Send(params)
	return err
}

func seededRandom(seed int) float64 {
	var x = math.Sin(float64(seed)) * 1000
	return x - math.Floor(x)
}
