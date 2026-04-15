package service

import (
	"context"
	"errors"
	"fmt"

	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"
)

type CommentService struct {
	commentRepository   repositories.CommentRepository
	postRepository      repositories.PostRepository
	notificationService notification.Service
	userRepository      user.Store
	likeRepository      repositories.LikeRepository
	bucketRepository    bucket.Repository
}

func NewCommentService(
	commentRepo repositories.CommentRepository,
	postRepository repositories.PostRepository,
	notificationService notification.Service,
	userRepository user.Store,
	likeRepository repositories.LikeRepository,
	bucketRepository bucket.Repository,
) *CommentService {
	return &CommentService{
		commentRepository:   commentRepo,
		postRepository:      postRepository,
		notificationService: notificationService,
		userRepository:      userRepository,
		likeRepository:      likeRepository,
		bucketRepository:    bucketRepository,
	}
}

// AddCommentToPost adds a comment to a post and creates a notification
func (s *CommentService) AddCommentToPost(ctx context.Context, currentUser models.PublicUser, postId int, content string, imageKeyMap map[int]models.ImageData) (*models.DetailedComment, error) {
	post, err := s.postRepository.GetPostById(ctx, postId, currentUser.UserID)
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	commentFacets, err := utilities.GenerateFacets(ctx, s.userRepository, content)
	if err != nil {
		return nil, errors.New("unable to generate facets")
	}
	comment, err := s.commentRepository.AddCommentToPost(ctx, currentUser.UserID, postId, content, commentFacets)
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
			ImageBlobUrl: *presignedUrl,
			DisplayOrder: 0,
		})
	}

	commentId := comment.CommentID

	if currentUser.UserID != post.UserID {
		text := fmt.Sprintf("@%s commented on your post.", currentUser.Username)
		_, err = s.notificationService.AddNotification(ctx, post.UserID, postId, &commentId, text, models.NotificationTypeComment)
		if err != nil {
			return nil, err
		}
	}

	// also send notifications to mentioned users
	usersToNotify := map[int]bool{}
	for _, facet := range commentFacets {
		if facet.UserId != post.UserID && facet.UserId != currentUser.UserID {
			usersToNotify[facet.UserId] = true
		}
	}

	for userId := range usersToNotify {
		text := fmt.Sprintf("@%s mentioned you in a comment.", currentUser.Username)
		_, err = s.notificationService.AddNotification(ctx, userId, postId, &commentId, text, models.NotificationTypeMention)
		if err != nil {
			return nil, errors.New("unable to create a new comment notification")
		}
	}

	detailedComment := models.DetailedComment{
		CommentID: comment.CommentID,
		PostID:    comment.PostID,
		UserID:    comment.UserID,
		Text:      comment.Text,
		Facets:    comment.Facets,
		CreatedAt: comment.CreatedAt.Time,
		User:      currentUser,
		IsLiked:   false,
		Images:    commentImages,
	}

	return &detailedComment, nil
}

// GetCommentsByPostId retrieves all comments for a specific post with like status
func (s *CommentService) GetCommentsByPostId(ctx context.Context, currentUser models.PublicUser, postID int) ([]models.DetailedComment, error) {

	dbComments, err := s.commentRepository.GetCommentsByPostId(ctx, postID, currentUser.UserID)
	if err != nil {
		return nil, errors.New("unable to find comments")
	}

	comments := make([]models.DetailedComment, 0, len(dbComments))
	for _, dbComment := range dbComments {

		user, err := s.userRepository.GetUserById(ctx, dbComment.UserID)
		if err != nil {
			return nil, errors.New("unable to retrieve user associated with comment")
		}

		isLiked, err := s.likeRepository.IsLiked(
			ctx,
			currentUser.UserID,
			dbComment.PostID,
			&dbComment.CommentID,
		)
		if err != nil {
			return nil, errors.New("unable to retrieve comment liked information")
		}

		dbImages, err := s.commentRepository.GetImagesByCommentId(ctx, dbComment.CommentID)
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
				PostId:       postID,
				Height:       image.Height,
				Width:        image.Width,
				ImageBlobUrl: *blobUrl,
				DisplayOrder: 0,
			}

			images = append(images, currentImage)
		}

		if len(dbImages) > 0 {
			if !utilities.IsAppUpdatedToVersion(ctx, "v1.8.0") {
				prefix := ""
				if dbComment.Text != "" {
					prefix = "\n\n"
				}
				dbComment.Text = dbComment.Text + prefix + "→ [Update Splajompy](https://apps.apple.com/us/app/splajompy/id6744034321) to view the image in this comment."
			}
		}

		detailedComment := models.DetailedComment{
			CommentID: dbComment.CommentID,
			PostID:    dbComment.PostID,
			UserID:    dbComment.UserID,
			Text:      dbComment.Text,
			Facets:    dbComment.Facets,
			Images:    images,
			CreatedAt: dbComment.CreatedAt.Time,
			User:      user,
			IsLiked:   isLiked,
		}

		comments = append(comments, detailedComment)
	}

	return comments, nil
}

// AddLikeToCommentById adds a like to a comment
func (s *CommentService) AddLikeToCommentById(ctx context.Context, currentUser models.PublicUser, postId int, commentId int) error {
	err := s.likeRepository.AddLike(ctx, currentUser.UserID, postId, &commentId)
	if err != nil {
		return errors.New("unable to add like to comment")
	}

	comment, err := s.commentRepository.GetCommentById(ctx, commentId)
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
func (s *CommentService) RemoveLikeFromCommentById(ctx context.Context, user models.PublicUser, postId int, commentId int) error {
	err := s.likeRepository.RemoveLike(ctx, user.UserID, postId, &commentId)
	if err != nil {
		return errors.New("unable to remove like from comment")
	}

	return s.notificationService.RemoveLikeNotification(ctx, user.UserID, postId, &commentId)
}

// DeleteComment deletes a comment by ID if the current user owns it
func (s *CommentService) DeleteComment(ctx context.Context, currentUser models.PublicUser, commentId int) error {
	comment, err := s.commentRepository.GetCommentById(ctx, commentId)
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
