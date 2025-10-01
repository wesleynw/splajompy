package service

import (
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"sort"
	"time"

	"github.com/resend/resend-go/v2"
	"golang.org/x/mod/semver"
	"golang.org/x/sync/errgroup"
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

		_, err = s.postRepository.InsertImage(ctx, post.PostID, imageData.Height, imageData.Width, destinationKey, displayOrder)
		if err != nil {
			return errors.New("unable to create post")
		}
	}

	// send notifications to users who are mentioned in post
	usersToNotify := map[int]bool{}
	for _, facet := range facets {
		if facet.UserId != currentUser.UserID {
			usersToNotify[facet.UserId] = true
		}
	}

	for userId := range usersToNotify {
		text := fmt.Sprintf("@%s mentioned you in a post.", currentUser.Username)
		notificationFacets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return err
		}

		err = s.notificationRepository.InsertNotification(ctx, userId, &postId, nil, &notificationFacets, text, models.NotificationTypeMention, nil)
		if err != nil {
			return errors.New("unable to create post")
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

	user, err := s.userRepository.GetUserById(ctx, post.UserID)
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

	pinnedPostId, _ := s.postRepository.GetPinnedPostId(ctx, post.UserID)
	isPinned := pinnedPostId != nil && *pinnedPostId == postId

	versionAny := ctx.Value(middleware.AppVersionKey)
	version, ok := versionAny.(string)
	if pollDetails != nil && (!ok || version == "unknown" || semver.Compare("v"+version, "v1.3.0") < 0) {
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
		IsPinned:      isPinned,
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
		postIDs[i] = row.PostID
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIDs)
}

func (s *PostService) getPostsByPostIDs(ctx context.Context, currentUser models.PublicUser, postIDs []int) (*[]models.DetailedPost, error) {
	posts := make([]models.DetailedPost, len(postIDs))

	g, ctx := errgroup.WithContext(ctx)

	for i, postID := range postIDs {
		g.Go(func() error {
			post, err := s.GetPostById(ctx, currentUser, postID)
			if err != nil {
				return fmt.Errorf("unable to retrieve post %d", postID)
			}
			posts[i] = *post
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		return nil, err
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

	if currentUser.UserID != post.UserID {
		text := fmt.Sprintf("@%s liked your post.", currentUser.Username)
		facets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return err
		}
		err = s.notificationRepository.InsertNotification(ctx, post.UserID, &postId, nil, &facets, text, models.NotificationTypeLike, nil)
		if err != nil {
			return err
		}
	}

	return err
}

// RemoveLikeFromPost removes the current user's like from a post and deletes
// related notifications created within the last 5 minutes.
func (s *PostService) RemoveLikeFromPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.likeRepository.RemoveLike(ctx, currentUser.UserID, postId, true)
	if err != nil {
		return err
	}

	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return err
	}

	notification, err := s.notificationRepository.FindUnreadLikeNotification(ctx, post.UserID, postId, nil)
	if err == nil && notification != nil {
		if time.Since(notification.CreatedAt) <= 5*time.Minute {
			err = s.notificationRepository.DeleteNotificationById(ctx, notification.NotificationID)
			if err != nil {
				return err
			}
		}
	}

	return nil
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
	likes, err := s.likeRepository.GetPostLikesFromFollowers(ctx, postId, currentUser.UserID)
	if err != nil {
		return nil, false, err
	}

	sort.SliceStable(likes, func(i, j int) bool {
		return seededRandom(postId+likes[i].UserID) < seededRandom(postId+likes[j].UserID)
	})

	count := min(len(likes), 2)

	mappedLikes := make([]models.RelevantLike, count)
	userIDs := make([]int, count+1)
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
		voteCountMap[voteRow.OptionIndex] = voteRow.Count
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
	if currentUser.UserID != post.UserID {
		optionTitle := post.Attributes.Poll.Options[optionIndex]
		text := fmt.Sprintf("@%s voted \"%s\" in your poll.", currentUser.Username, optionTitle)
		facets, err := repositories.GenerateFacets(ctx, s.userRepository, text)
		if err != nil {
			return err
		}
		err = s.notificationRepository.InsertNotification(ctx, post.UserID, &postId, nil, &facets, text, models.NotificationTypePoll, nil)
		if err != nil {
			return err
		}
	}

	return nil
}

type FeedType string

const (
	FeedTypeAll       FeedType = "all"
	FeedTypeFollowing FeedType = "following"
	FeedTypeMutual    FeedType = "mutual"
	FeedTypeProfile   FeedType = "profile"
)

func (s *PostService) GetPostsWithTimeOffset(ctx context.Context, currentUser models.PublicUser, feedType FeedType, userId *int, limit int, beforeTimestamp *time.Time) (*[]models.DetailedPost, error) {
	var postIDs []int
	var err error

	switch feedType {
	case FeedTypeAll:
		postIDs, err = s.postRepository.GetAllPostIdsCursor(ctx, limit, beforeTimestamp, currentUser.UserID)
	case FeedTypeFollowing:
		postIDs, err = s.postRepository.GetPostIdsForFollowingCursor(ctx, currentUser.UserID, limit, beforeTimestamp)
	case FeedTypeMutual:
		postRows, mutualErr := s.postRepository.GetPostIdsForMutualFeedCursor(ctx, currentUser.UserID, limit, beforeTimestamp)
		if mutualErr != nil {
			return nil, mutualErr
		}
		postIDs = make([]int, len(postRows))
		for i, row := range postRows {
			postIDs[i] = row.PostID
		}
	case FeedTypeProfile:
		if userId == nil {
			return nil, errors.New("userId required for profile feed")
		}
		postIDs, err = s.postRepository.GetPostIdsByUserIdCursor(ctx, *userId, limit, beforeTimestamp)

		if err == nil {
			// get pinned post id for filtering (only for version >= 1.4.0)
			versionAny := ctx.Value(middleware.AppVersionKey)
			version, ok := versionAny.(string)
			if ok && version != "unknown" && semver.Compare("v"+version, "v1.4.0") >= 0 {
				pinnedPostId, _ := s.postRepository.GetPinnedPostId(ctx, *userId)

				if pinnedPostId != nil {
					// filter out pinned post from regular results
					filteredIds := make([]int, 0, len(postIDs))
					for _, id := range postIDs {
						if id != *pinnedPostId {
							filteredIds = append(filteredIds, id)
						}
					}
					postIDs = filteredIds

					// for first page, prepend pinned post
					if beforeTimestamp == nil {
						postIDs = append([]int{*pinnedPostId}, postIDs...)
					}
				}
			}
		}
	default:
		return nil, errors.New("invalid feed type")
	}

	if err != nil {
		return nil, err
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIDs)
}

func seededRandom(seed int) float64 {
	var x = math.Sin(float64(seed)) * 1000
	return x - math.Floor(x)
}

// PinPost pins a post for the current user
func (s *PostService) PinPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId)
	if err != nil {
		return errors.New("post not found")
	}

	if post.UserID != currentUser.UserID {
		return errors.New("can only pin your own posts")
	}

	return s.postRepository.PinPost(ctx, currentUser.UserID, postId)
}

// UnpinPost unpins the currently pinned post for the user
func (s *PostService) UnpinPost(ctx context.Context, currentUser models.PublicUser) error {
	return s.postRepository.UnpinPost(ctx, currentUser.UserID)
}

// GetPinnedPostId retrieves the pinned post ID for a user
func (s *PostService) GetPinnedPostId(ctx context.Context, userId int) (*int, error) {
	return s.postRepository.GetPinnedPostId(ctx, userId)
}
