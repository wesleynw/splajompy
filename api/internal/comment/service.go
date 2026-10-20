package comment

import (
	"context"
	"errors"
	"fmt"

	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/like"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"
)

var ErrCommentNotFound = errors.New("this comment does not exist")
var ErrCommentReplyNotAllowed = errors.New("now allowed to reply to this comment")

type Service struct {
	commentRepository   *Store
	postRepository      post.Store
	notificationService notification.Service
	userRepository      user.Store
	likeRepository      like.Store
	bucketRepository    bucket.Repository
}

func NewService(
	commentRepo *Store,
	postRepository post.Store,
	notificationService notification.Service,
	userRepository user.Store,
	likeRepository like.Store,
	bucketRepository bucket.Repository,
) *Service {
	return &Service{
		commentRepository:   commentRepo,
		postRepository:      postRepository,
		notificationService: notificationService,
		userRepository:      userRepository,
		likeRepository:      likeRepository,
		bucketRepository:    bucketRepository,
	}
}

// AddComment adds a comment to a post or comment and creates a notification
func (s *Service) AddComment(ctx context.Context, currentUser models.PublicUser, postId int, commentId *int, content string, imageKeyMap map[int]models.ImageData) (*models.DetailedComment, error) {
	targetPost, err := s.postRepository.GetPostById(ctx, postId, currentUser.UserID)
	if err != nil {
		return nil, post.ErrPostNotFound
	}

	if commentId != nil {
		targetComment, err := s.commentRepository.GetCommentById(ctx, currentUser.UserID, *commentId)
		if err != nil {
			return nil, ErrCommentNotFound
		}
		if targetComment.ParentCommentID != nil {
			return nil, ErrCommentReplyNotAllowed
		}
	}

	commentFacets, err := utilities.GenerateFacets(ctx, s.userRepository, content)
	if err != nil {
		return nil, errors.New("unable to generate facets")
	}
	comment, err := s.commentRepository.AddCommentToPost(ctx, currentUser.UserID, postId, content, commentFacets, commentId)
	if err != nil {
		return nil, errors.New("unable to create new comment")
	}

	// TODO: unpublish images and rest of comment on failure w/ images
	imageBlobUrls, err := s.bucketRepository.PublishStagedImages(ctx, currentUser.UserID, "comment", comment.CommentID, imageKeyMap)
	if err != nil {
		return nil, err
	}

	commentImages := []models.DetailedImage{}
	for i, blobUrl := range imageBlobUrls {
		image, err := s.commentRepository.InsertImage(ctx, comment.CommentID, imageKeyMap[i].Height, imageKeyMap[i].Width, blobUrl, 0)
		if err != nil {
			return nil, err
		}

		presignedUrl, err := s.bucketRepository.GetPresignedGetObject(ctx, blobUrl)
		if err != nil {
			return nil, err
		}

		commentImages = append(commentImages, models.DetailedImage{
			ImageID:      image.ImageID,
			PostId:       postId,
			Height:       image.Height,
			Width:        image.Width,
			ImageBlobUrl: presignedUrl,
			DisplayOrder: 0,
		})
	}

	newCommentId := comment.CommentID

	if currentUser.UserID != targetPost.UserID {
		text := fmt.Sprintf("@%s commented", currentUser.Username)
		_, err = s.notificationService.AddNotification(ctx, targetPost.UserID, &postId, &newCommentId, nil, text, models.NotificationTypeComment, &comment.Text)
		if err != nil {
			return nil, err
		}
	}

	// also send notifications to mentioned users
	usersToNotify := map[int]bool{}
	for _, facet := range commentFacets {
		if facet.UserId != targetPost.UserID && facet.UserId != currentUser.UserID {
			usersToNotify[facet.UserId] = true
		}
	}

	for userId := range usersToNotify {
		text := fmt.Sprintf("@%s mentioned you", currentUser.Username)
		_, err = s.notificationService.AddNotification(ctx, userId, &postId, &newCommentId, nil, text, models.NotificationTypeMention, &comment.Text)
		if err != nil {
			return nil, errors.New("unable to create a new comment notification")
		}
	}

	detailedComment := models.DetailedComment{
		CommentID:       comment.CommentID,
		PostID:          comment.PostID,
		UserID:          comment.UserID,
		Text:            comment.Text,
		Facets:          comment.Facets,
		CreatedAt:       comment.CreatedAt,
		User:            currentUser,
		IsLiked:         false,
		Images:          commentImages,
		ParentCommentId: commentId,
	}

	return &detailedComment, nil
}

// GetCommentsByPostId retrieves all comments for a specific post with like status
func (s *Service) GetCommentsByPostId(ctx context.Context, currentUser models.PublicUser, postID int) ([]models.DetailedComment, error) {

	dbComments, err := s.commentRepository.GetCommentsByPostId(ctx, postID, currentUser.UserID)
	if err != nil {
		return nil, errors.New("unable to find comments")
	}

	comments := make([]models.DetailedComment, 0, len(dbComments))
	for _, dbComment := range dbComments {
		comment, err := s.hydrateComment(ctx, postID, currentUser, dbComment, 0)
		if err != nil {
			return nil, errors.New("unable to retrieve user associated with comment")
		}

		comments = append(comments, *comment)
	}

	return comments, nil
}

// AddLikeToCommentById adds a like to a comment
func (s *Service) AddLikeToCommentById(ctx context.Context, currentUser models.PublicUser, postId int, commentId int) error {
	err := s.likeRepository.AddLike(ctx, currentUser.UserID, postId, &commentId)
	if err != nil {
		return errors.New("unable to add like to comment")
	}

	comment, err := s.commentRepository.GetCommentById(ctx, currentUser.UserID, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	if currentUser.UserID != comment.UserID {
		err = s.notificationService.AddLikeNotification(ctx, currentUser.UserID, postId, &commentId)
		if err != nil {
			return err
		}
	}

	return nil
}

// RemoveLikeFromCommentById removes the current user's like from a comment and
// deletes related notifications.
func (s *Service) RemoveLikeFromCommentById(ctx context.Context, user models.PublicUser, postId int, commentId int) error {
	err := s.likeRepository.RemoveLike(ctx, user.UserID, postId, &commentId)
	if err != nil {
		return errors.New("unable to remove like from comment")
	}

	return s.notificationService.RemoveLikeNotification(ctx, user.UserID, postId, &commentId)
}

// DeleteComment deletes a comment by ID if the current user owns it
func (s *Service) DeleteComment(ctx context.Context, currentUser models.PublicUser, commentId int) error {
	comment, err := s.commentRepository.GetCommentById(ctx, currentUser.UserID, commentId)
	if err != nil {
		return errors.New("unable to find comment")
	}

	if comment.UserID != currentUser.UserID {
		return errors.New("unable to delete comment")
	}

	images, err := s.commentRepository.GetImagesByCommentId(ctx, commentId)
	if err != nil {
		return errors.New("unable to retrieve comment images")
	}

	if err := s.commentRepository.DeleteComment(ctx, commentId); err != nil {
		return err
	}

	if len(images) > 0 {
		keys := make([]string, len(images))
		for i, img := range images {
			keys[i] = img.ImageBlobUrl
		}
		if err := s.bucketRepository.DeleteObjects(ctx, keys); err != nil {
			return errors.New("unable to delete comment images from storage")
		}
	}

	return nil
}

func (s *Service) hydrateComment(ctx context.Context, postId int, currentUser models.PublicUser, comment queries.Comment, threadDepth int) (*models.DetailedComment, error) {
	if threadDepth > 1 {
		return nil, ErrCommentReplyNotAllowed
	}

	user, err := s.userRepository.GetUserById(ctx, comment.UserID)
	if err != nil {
		return nil, errors.New("unable to retrieve user associated with comment")
	}

	isLiked, err := s.likeRepository.IsLiked(
		ctx,
		currentUser.UserID,
		comment.PostID,
		&comment.CommentID,
	)
	if err != nil {
		return nil, errors.New("unable to retrieve comment liked information")
	}

	dbImages, err := s.commentRepository.GetImagesByCommentId(ctx, comment.CommentID)
	if err != nil {
		return nil, err
	}
	images := []models.DetailedImage{}
	for _, image := range dbImages {
		blobUrl, err := s.bucketRepository.GetPresignedGetObject(ctx, image.ImageBlobUrl)
		if err != nil {
			return nil, err
		}

		currentImage := models.DetailedImage{
			ImageID:      image.ImageID,
			PostId:       postId,
			Height:       image.Height,
			Width:        image.Width,
			ImageBlobUrl: blobUrl,
			DisplayOrder: 0,
		}

		images = append(images, currentImage)
	}

	if len(dbImages) > 0 {
		if !utilities.IsAppUpdatedToVersion(ctx, "v1.8.0") {
			prefix := ""
			if comment.Text != "" {
				prefix = "\n\n"
			}
			comment.Text = comment.Text + prefix + "→ [Update Splajompy](https://apps.apple.com/us/app/splajompy/id6744034321) to view the image in this comment."
		}
	}

	children, err := s.commentRepository.GetCommentsByParentCommentId(ctx, comment.CommentID, currentUser.UserID)
	if err != nil {
		return nil, err
	}

	var hydratedChildren []models.DetailedComment
	if !utilities.IsAppUpdatedToVersion(ctx, "v1.13.0") {
		if len(comment.Text) != 0 {
			comment.Text = comment.Text + "\n\n"
		}
		comment.Text = comment.Text + "[Update Splajompy](https://apps.apple.com/us/app/splajompy/id6744034321) to view replies to this comment."
	} else {
		for _, child := range children {
			hydratedChild, err := s.hydrateComment(ctx, postId, currentUser, child, 1)
			if err != nil {
				return nil, err
			}
			hydratedChildren = append(hydratedChildren, *hydratedChild)
		}
	}

	detailedComment := models.DetailedComment{
		CommentID:       comment.CommentID,
		PostID:          comment.PostID,
		UserID:          comment.UserID,
		Text:            comment.Text,
		Facets:          comment.Facets,
		Images:          images,
		CreatedAt:       comment.CreatedAt,
		User:            user,
		IsLiked:         isLiked,
		Children:        hydratedChildren,
		ParentCommentId: comment.ParentCommentID,
	}

	return &detailedComment, nil
}
