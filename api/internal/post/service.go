package post

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/resend/resend-go/v3"
	"golang.org/x/sync/errgroup"
	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/like"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/templates"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"
)

type Service struct {
	postRepository      Store
	userRepository      user.Store
	likeRepository      like.Store
	notificationService notification.Service
	bucketRepository    bucket.Repository
	emailService        *resend.Client
}

func NewService(postRepository Store, userRepository user.Store, likeRepository like.Store, notificationService notification.Service, bucketRepo bucket.Repository, emailService *resend.Client) *Service {
	return &Service{
		postRepository:      postRepository,
		userRepository:      userRepository,
		likeRepository:      likeRepository,
		notificationService: notificationService,
		bucketRepository:    bucketRepo,
		emailService:        emailService,
	}
}

// NewPost preprocesses a new post and stores it in the database.
func (s *Service) NewPost(ctx context.Context, currentUser models.PublicUser, text string, imageKeymap map[int]models.ImageData, poll *db.Poll, visibilityEnum *int) (*models.Post, error) {
	facets, err := utilities.GenerateFacets(ctx, s.userRepository, text)
	if err != nil {
		return nil, err
	}

	var attributes *db.Attributes
	if poll != nil {
		attributes = &db.Attributes{
			Poll: *poll,
		}
	}

	var visibilityType = models.VisibilityPublic
	if visibilityEnum != nil {
		visibilityType = models.VisibilityTypeEnum(*visibilityEnum)
	}

	post, err := s.postRepository.InsertPost(ctx, currentUser.UserID, text, facets, attributes, &visibilityType)
	if err != nil {
		return nil, errors.New("unable to create post")
	}
	postId := post.PostID

	imageBlobKeys, err := s.bucketRepository.PublishStagedImages(ctx, currentUser.UserID, "post", postId, imageKeymap)
	if err != nil {
		return nil, err
	}

	for i, blobKey := range imageBlobKeys {
		_, err = s.postRepository.InsertImage(ctx, post.PostID, imageKeymap[i].Height, imageKeymap[i].Width, blobKey, i)
		if err != nil {
			return nil, errors.New("unable to create post")
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
		text := fmt.Sprintf("@%s mentioned you in a post", currentUser.Username)
		_, err = s.notificationService.AddNotification(ctx, userId, postId, nil, text, models.NotificationTypeMention, &post.Text)
		if err != nil {
			return nil, err
		}
	}

	return post, nil
}

func (s *Service) NewPresignedStagingUrl(ctx context.Context, currentUser models.PublicUser, extension *string, folder *string) (string, string, error) {
	return s.bucketRepository.GetPresignedPutObject(ctx, currentUser.UserID, extension, folder)
}

// GetPostById fetches a post by its id.
func (s *Service) GetPostById(ctx context.Context, userId int, postId int) (*models.DetailedPost, error) {
	post, err := s.postRepository.GetPostById(ctx, postId, userId)
	if err != nil {
		return nil, err
	}

	user, err := s.userRepository.GetUserById(ctx, post.UserID)
	if err != nil {
		return nil, err
	}

	isLiked, _ := s.postRepository.IsPostLikedByUserId(ctx, userId, post.PostID)

	images, _ := s.postRepository.GetImagesForPost(ctx, post.PostID)
	if images == nil {
		images = []queries.Image{}
	}
	detailedImages := []models.DetailedImage{}
	for i, image := range images {
		url, err := s.bucketRepository.GetPresignedGetObject(ctx, images[i].ImageBlobUrl)
		if err != nil {
			return nil, errors.New("unable to generate presigned url for post image")
		}
		detailedImages = append(detailedImages, models.DetailedImage{
			ImageID:      image.ImageID,
			PostId:       postId,
			Height:       image.Height,
			Width:        image.Width,
			ImageBlobUrl: *url,
			DisplayOrder: i,
		})
	}

	commentCount, _ := s.postRepository.GetCommentCountForPost(ctx, post.PostID)
	relevantLikes, hasOtherLikes, _ := s.getRelevantLikes(ctx, userId, postId)

	var pollDetails *models.DetailedPoll
	if post.Attributes != nil {
		pollDetails, err = s.GetPollDetails(ctx, userId, postId, post.Attributes.Poll)
		if err != nil {
			return nil, err
		}
	}

	pinnedPostId, _ := s.postRepository.GetPinnedPostId(ctx, post.UserID)
	isPinned := pinnedPostId != nil && *pinnedPostId == postId

	if pollDetails != nil && !utilities.IsAppUpdatedToVersion(ctx, "v1.3.0") {
		if post.Text != "" {
			post.Text += "\n\n"
		}
		post.Text += "This post contains a poll. Please update your app to view it."
	}

	return &models.DetailedPost{
		Post:          *post,
		User:          user,
		IsLiked:       isLiked,
		Images:        detailedImages,
		CommentCount:  commentCount,
		RelevantLikes: relevantLikes,
		HasOtherLikes: hasOtherLikes,
		Poll:          pollDetails,
		IsPinned:      isPinned,
	}, nil
}

func (s *Service) getPostsByPostIDs(ctx context.Context, currentUser models.PublicUser, postIDs []int) ([]models.DetailedPost, error) {
	posts := make([]models.DetailedPost, len(postIDs))

	g, ctx := errgroup.WithContext(ctx)

	for i, postID := range postIDs {
		g.Go(func() error {
			post, err := s.GetPostById(ctx, currentUser.UserID, postID)
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

	return posts, nil
}

func (s *Service) AddLikeToPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.likeRepository.AddLike(ctx, currentUser.UserID, postId, nil)
	if err != nil {
		return err
	}

	return s.notificationService.AddLikeNotification(ctx, currentUser.UserID, postId, nil)
}

// RemoveLikeFromPost removes the current user's like from a post and deletes
// related notifications created within the last 5 minutes.
func (s *Service) RemoveLikeFromPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	err := s.likeRepository.RemoveLike(ctx, currentUser.UserID, postId, nil)
	if err != nil {
		return err
	}

	return s.notificationService.RemoveLikeNotification(ctx, currentUser.UserID, postId, nil)
}

func (s *Service) DeletePost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUser.UserID)
	if err != nil {
		return err
	}

	if post.UserID != currentUser.UserID {
		return errors.New("unable to delete post")
	}

	return s.postRepository.DeletePost(ctx, postId)
}

// getRelevantLikes deterministically returns a short list of other users who have liked a given post,
// along with a bool indicating whether there are more likers beyond the returned slice.
func (s *Service) getRelevantLikes(ctx context.Context, userId int, postId int) ([]models.RelevantLike, bool, error) {
	likes, err := s.likeRepository.GetOtherPostLikes(ctx, postId, userId)
	if err != nil {
		return nil, false, err
	}

	sort.SliceStable(likes, func(i, j int) bool {
		return utilities.SeededRandom(postId+likes[i].UserID) < utilities.SeededRandom(postId+likes[j].UserID)
	})

	hasOtherLikes := len(likes) > 2
	count := min(len(likes), 2)

	mappedLikes := make([]models.RelevantLike, count)
	for i, like := range likes[:count] {
		mappedLikes[i] = models.RelevantLike{
			Username: like.Username,
			UserID:   like.UserID,
		}
	}

	return mappedLikes, hasOtherLikes, nil
}

func (s *Service) ReportPost(ctx context.Context, currentUser *models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUser.UserID)
	if err != nil {
		return err
	}

	author, err := s.userRepository.GetUserById(ctx, post.UserID)
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
		url, err := s.bucketRepository.GetPresignedGetObject(ctx, images[i].ImageBlobUrl)
		if err != nil {
			slog.ErrorContext(ctx, "unable to generate presigned url")
			return nil
		}

		images[i].ImageBlobUrl = *url
	}

	html, err := templates.GeneratePostReportEmail(currentUser.Username, author.Username, author.UserID, *post, images)
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

func (s *Service) GetPollDetails(ctx context.Context, userId int, postId int, poll db.Poll) (*models.DetailedPoll, error) {
	currentUserVote, err := s.postRepository.GetUserVoteInPoll(ctx, postId, userId)
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

func (s *Service) VoteOnPoll(ctx context.Context, currentUser models.PublicUser, postId int, optionIndex int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUser.UserID)
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
		text := fmt.Sprintf("@%s voted \"%s\" in your poll", currentUser.Username, optionTitle)
		_, err = s.notificationService.AddNotification(ctx, post.UserID, postId, nil, text, models.NotificationTypePoll, nil)
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

// GetPosts returns paginated posts from the source defined by feedType
func (s *Service) GetPosts(ctx context.Context, currentUser models.PublicUser, feedType FeedType, userId *int, limit int, beforeTimestamp *time.Time) ([]models.DetailedPost, error) {
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

		var pinnedPostId *int
		if utilities.IsAppUpdatedToVersion(ctx, "v1.4.0") {
			pinnedPostId, _ = s.postRepository.GetPinnedPostId(ctx, *userId)
		}

		postIDs, err = s.postRepository.GetPostIdsByUserIdCursor(ctx, currentUser.UserID, *userId, limit, beforeTimestamp)

		// for first page, prepend pinned post
		if err == nil && pinnedPostId != nil && beforeTimestamp == nil {
			postIDs = append([]int{*pinnedPostId}, postIDs...)
		}
	default:
		return nil, errors.New("invalid feed type")
	}

	if err != nil {
		return nil, err
	}

	return s.getPostsByPostIDs(ctx, currentUser, postIDs)
}

// PinPost pins a post for the current user
func (s *Service) PinPost(ctx context.Context, currentUser models.PublicUser, postId int) error {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUser.UserID)
	if err != nil {
		return errors.New("post not found")
	}

	if post.UserID != currentUser.UserID {
		return errors.New("can only pin your own posts")
	}

	return s.postRepository.PinPost(ctx, currentUser.UserID, postId)
}

// UnpinPost unpins the currently pinned post for the user
func (s *Service) UnpinPost(ctx context.Context, currentUser models.PublicUser) error {
	return s.postRepository.UnpinPost(ctx, currentUser.UserID)
}

// GetPinnedPostId retrieves the pinned post ID for a user
func (s *Service) GetPinnedPostId(ctx context.Context, userId int) (*int, error) {
	return s.postRepository.GetPinnedPostId(ctx, userId)
}
