package service

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgtype"
	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/models"
)

type CommentService struct {
	queries *db.Queries
}

func NewCommentService(queries *db.Queries) *CommentService {
	return &CommentService{
		queries: queries,
	}
}

func (s *CommentService) AddCommentToPost(ctx context.Context, cUser models.PublicUser, postID int, content string) (*db.Comment, error) {
	_, err := s.queries.GetPostById(ctx, int32(postID))
	if err != nil {
		return nil, errors.New("unable to find post")
	}

	comment, err := s.queries.AddCommentToPost(ctx, db.AddCommentToPostParams{
		PostID: int32(postID),
		UserID: cUser.UserID,
		Text:   content,
	})
	if err != nil {
		return nil, errors.New("unable to create new comment")
	}

	return &comment, nil
}

func (s *CommentService) GetCommentsByPostId(ctx context.Context, cUser models.PublicUser, postID int) (*[]models.DetailedComment, error) {
	dbComments, err := s.queries.GetCommentsByPostId(ctx, int32(postID))
	if err != nil {
		return nil, errors.New("unable to find comments")
	}
	if dbComments == nil {
		dbComments = []db.GetCommentsByPostIdRow{}
	}

	comments := []models.DetailedComment{}

	for i := range len(dbComments) {
		dbComment := dbComments[i]

		isLiked, err := s.queries.GetIsLikedByUser(ctx, db.GetIsLikedByUserParams{
			UserID:    cUser.UserID,
			PostID:    int32(postID),
			CommentID: pgtype.Int4{Int32: int32(dbComment.CommentID), Valid: true},
			Column4:   false,
		})
		if err != nil {
			return nil, errors.New("unable to retrieve comment liked information")
		}

		dbUser, err := s.queries.GetUserById(ctx, dbComment.UserID)
		if err != nil {
			return nil, errors.New("unable to retrive user associated with comment")
		}

		var user = models.PublicUser(dbUser)

		detailedComment := models.DetailedComment{
			CommentID: dbComment.CommentID,
			PostID:    dbComment.PostID,
			UserID:    dbComment.UserID,
			Text:      dbComment.Text,
			CreatedAt: dbComment.CreatedAt,
			User:      user,
			IsLiked:   isLiked,
		}

		comments = append(comments, detailedComment)
	}

	return &comments, nil
}

func (s *CommentService) AddLikeToCommentById(ctx context.Context, cUser models.PublicUser, postID int, commentID int) error {
	err := s.queries.AddLike(ctx, db.AddLikeParams{
		PostID:    int32(postID),
		CommentID: pgtype.Int4{Int32: int32(commentID), Valid: true},
		UserID:    cUser.UserID,
		IsPost:    false,
	})

	return err
}

func (s *CommentService) RemoveLikeFromCommentById(ctx context.Context, cUser models.PublicUser, postID int, commentID int) error {
	err := s.queries.RemoveLike(ctx, db.RemoveLikeParams{
		PostID:    int32(postID),
		CommentID: pgtype.Int4{Int32: int32(commentID), Valid: true},
		UserID:    cUser.UserID,
		IsPost:    false,
	})

	return err
}
