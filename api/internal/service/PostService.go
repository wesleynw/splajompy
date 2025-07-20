package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/resend/resend-go/v2"
	"golang.org/x/mod/semver"
	"math"
	"os"
	"sort"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/templates"
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

func (s *PostService) NewPost(ctx context.Context, currentUser models.PublicUser, text string, imageKeymap map[int]models.ImageData, poll *db.Poll) error {
	facets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
	if err != nil {
		return err
	}

	var attributes *db.Attributes
	if poll != nil {
		attributes = &db.Attributes{
			Poll: *poll,
		}
	}

	post, err := s.postRepository.InsertPost(ctx, currentUser.UserID, text, facets, attributes)
	if err != nil {
		return errors.New("unable to create post")
	}
	postId := post.PostID

	environment := os.Getenv("ENVIRONMENT")

	for displayOrder, imageData := range imageKeymap {
		destinationKey := repositories.GetDestinationKey(
			environment,
			currentUser.UserID,
			post.PostID,
			imageData.S3Key,
		)

		err := s.bucketRepository.CopyObject(ctx, imageData.S3Key, destinationKey)
		if err != nil {
			return errors.New("unable to create post")
		}

		err = s.bucketRepository.DeleteObject(ctx, imageData.S3Key)
		if err != nil {
			return errors.New("unable to create post")
		}

		_, err = s.postRepository.InsertImage(ctx, post.PostID, imageData.Height, imageData.Width, destinationKey, int(int32(displayOrder)))
		if err != nil {
			return errors.New("unable to create post")
		}
	}

	// send notifications to users mentioned in post
	for _, facet := range facets {
		if facet.UserId != currentUser.UserID {
			text := fmt.Sprintf("@%s mentioned you in a post.", currentUser.Username)
			notificationFacets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
			if err != nil {
				return err
			}

			err = s.notificationRepository.InsertNotification(ctx, facet.UserId, &postId, nil, &notificationFacets, text, models.NotificationTypeMention)
			if err != nil {
				return errors.New("unable to create post")
			}
		}
	}

	return nil
}

func (s *PostService) NewPresignedStagingUrl(ctx context.Context, currentUser models.PublicUser, extension *string, folder *string) (string, string, error) {
	return s.bucketRepository.GeneratePresignedURL(ctx, currentUser.UserID, extension, folder)
}

func (s *PostService) GetPostById(ctx context.Context, currentUser models.PublicUser, postId int) (*models.DetailedPost, error) {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return nil, err
	}

	user, err := s.userRepository.GetUserById(ctx, int(post.UserID))
	if err != nil {
		return nil, err
	}

	isLiked, _ := s.postRepository.IsPostLikedByUserId(ctx, currentUser.UserID, post.PostID)

	images, _ := s.postRepository.GetImagesForPost(ctx, post.PostID)
	if images == nil {
		images = []queries.Image{}
	}
	for i := range images {
		images[i].ImageBlobUrl = s.bucketRepository.GetObjectURL(images[i].ImageBlobUrl)
	}

	commentCount, _ := s.postRepository.GetCommentCountForPost(ctx, post.PostID)
	relevantLikes, hasOtherLikes, _ := s.getRelevantLikes(ctx, currentUser, postId)

	var pollDetails *models.DetailedPoll
	if post.Attributes != nil {
		pollDetails, err = s.GetPollDetails(ctx, currentUser, postId, post.Attributes.Poll)
		if err != nil {
			return nil, err
		}
	}

	versionAny := ctx.Value(middleware.AppVersionKey)
	version, ok := versionAny.(string)
	if !ok || version == "unknown" || semver.Compare("v"+version, "v1.3.0") < 0 {
		if post.Text != "" {
			post.Text += "\n\n"
		}
		post.Text += "This post contains a poll. Please update your app to view it."
	}

	return &models.DetailedPost{
		Post:          *post,
		User:          user,
		IsLiked:       isLiked,
		Images:        images,
		CommentCount:  commentCount,
		RelevantLikes: relevantLikes,
		HasOtherLikes: hasOtherLikes,
		Poll:          pollDetails,
	}, nil
}

func (s *PostService) GetAllPosts(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.postRepository.GetAllPostIds(ctx, limit, offset, currentUser.UserID)
	if err != nil {
		return nil, err
	}
	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetPostsByUserId(ctx context.Context, currentUser models.PublicUser, userID int, limit int, offset int) (*[]models.DetailedPost, error) {
	if blocked, _ := s.userRepository.IsUserBlockingUser(ctx, userID, currentUser.UserID); blocked {
		return &[]models.DetailedPost{}, nil
	}

	postIds, err := s.postRepository.GetPostIdsForUser(ctx, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetPostsByFollowing(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postIds, err := s.postRepository.GetPostIdsForFollowing(ctx, currentUser.UserID, limit, offset)
	if err != nil {
		return nil, err
	}
	return s.getPostsByPostIDs(ctx, currentUser, postIds)
}

func (s *PostService) GetMutualFeed(ctx context.Context, currentUser models.PublicUser, limit int, offset int) (*[]models.DetailedPost, error) {
	postRows, err := s.postRepository.GetPostIdsForMutualFeed(ctx, currentUser.UserID, limit, offset)
	if err != nil {
		return nil, err
	}

	// Extract just the post IDs from the rows
	postIDs := make([]int, len(postRows))
	for i, row := range postRows {
		postIDs[i] = int(row.PostID)
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIDs)
}

func (s *PostService) getPostsByPostIDs(ctx context.Context, currentUser models.PublicUser, postIDs []int) (*[]models.DetailedPost, error) {
	var posts = make([]models.DetailedPost, 0)

	for i := range postIDs {
		post, err := s.GetPostById(ctx, currentUser, postIDs[i])
		if err != nil {
			return nil, fmt.Errorf("unable to retrieve post %d", postIDs[i])
		}
		posts = append(posts, *post)
	}

	return &posts, nil
}

func (s *PostService) AddLikeToPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.likeRepository.AddLike(ctx, currentUser.UserID, postId, true)
	if err != nil {
		return err
	}

	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	text := fmt.Sprintf("@%s liked your post.", currentUser.Username)
	facets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
	if err != nil {
		return err
	}
	err = s.notificationRepository.InsertNotification(ctx, int(post.UserID), &postId, nil, &facets, text, models.NotificationTypeLike)

	return err
}

func (s *PostService) RemoveLikeFromPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.likeRepository.RemoveLike(ctx, currentUser.UserID, postId, true)
	return err
}

func (s *PostService) DeletePost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	if int(post.UserID) != currentUser.UserID {
		return errors.New("unable to delete post")
	}

	return s.postRepository.DeletePost(ctx, postId)
}

func (s *PostService) getRelevantLikes(ctx context.Context, currentUser models.PublicUser, postId int) ([]models.RelevantLike, bool, error) {
	likes, err := s.likeRepository.GetPostLikesFromFollowers(ctx, postId, currentUser.UserID)
	if err != nil {
		return nil, false, err
	}

	sort.SliceStable(likes, func(i, j int) bool {
		return seededRandom(postId+int(likes[i].UserID)) < seededRandom(postId+int(likes[j].UserID))
	})

	count := min(len(likes), 2)

	mappedLikes := make([]models.RelevantLike, count)
	userIDs := make([]int32, count+1)
	for i, like := range likes[:count] {
		mappedLikes[i] = models.RelevantLike{
			Username: like.Username,
			UserID:   int(like.UserID),
		}
		userIDs[i] = like.UserID
	}

	// don't include the current user
	userIDs[count] = int32(currentUser.UserID)

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

	images, err := s.postRepository.GetImagesForPost(ctx, post.PostID)
	if err != nil {
		return err
	}
	if images == nil {
		images = []queries.Image{}
	}

	for i := range images {
		images[i].ImageBlobUrl = s.bucketRepository.GetObjectURL(images[i].ImageBlobUrl)
	}

	html, err := templates.GeneratePostReportEmail(currentUser.Username, *post, images)
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

func (s *PostService) GetPollDetails(ctx context.Context, currentUser models.PublicUser, postId int, poll db.Poll) (*models.DetailedPoll, error) {
	currentUserVote, err := s.postRepository.GetUserVoteInPoll(ctx, postId, currentUser.UserID)
	if err != nil {
		return nil, err
	}

	voteTotals, err := s.postRepository.GetPollVotesGrouped(ctx, postId)
	if err != nil {
		return nil, err
	}

	voteCountMap := make(map[int]int64)
	totalVotes := int64(0)
	for _, voteRow := range voteTotals {
		voteCountMap[int(voteRow.OptionIndex)] = voteRow.Count
		totalVotes += voteRow.Count
	}

	options := make([]models.DetailedPollOption, len(poll.Options))
	for i, option := range poll.Options {
		voteCount := voteCountMap[i]
		options[i] = models.DetailedPollOption{
			Title:     option,
			VoteTotal: int(voteCount),
		}
	}

	return &models.DetailedPoll{
		Title:           poll.Title,
		VoteTotal:       int(totalVotes),
		CurrentUserVote: currentUserVote,
		Options:         options,
	}, nil
}

func (s *PostService) VoteOnPoll(ctx context.Context, currentUser models.PublicUser, postId int, optionIndex int) error {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	if optionIndex < 0 || len(post.Attributes.Poll.Options) <= optionIndex {
		return errors.New("option index is out of range")
	}

	err = s.postRepository.InsertVote(ctx, postId, currentUser.UserID, optionIndex)
	if err != nil {
		return err
	}

	// send notification to poll owner (unless voting on own poll)
	if currentUser.UserID != int(post.UserID) {
		optionTitle := post.Attributes.Poll.Options[optionIndex]
		text := fmt.Sprintf("@%s voted \"%s\" in your poll.", currentUser.Username, optionTitle)
		facets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return err
		}
		err = s.notificationRepository.InsertNotification(ctx, int(post.UserID), &postId, nil, &facets, text, models.NotificationTypePoll)
		if err != nil {
			return err
		}
	}

	return nil
}

func seededRandom(seed int) float64 {
	var x = math.Sin(float64(seed)) * 1000
	return x - math.Floor(x)
}
