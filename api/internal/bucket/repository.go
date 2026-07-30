package bucket

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/cloudfront/sign"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/google/uuid"
	"splajompy.com/api/v2/internal/models"
)

type Repository interface {
	CopyObject(ctx context.Context, sourceKey, destinationKey string) error
	DeleteObject(ctx context.Context, key string) error
	DeleteObjects(ctx context.Context, keys []string) error
	GetPresignedPutObject(ctx context.Context, userID int, extension, folder string) (string, string, error)
	GetPresignedGetObject(ctx context.Context, key string) (string, error)
	PublishStagedImages(ctx context.Context, userId int, blobType string, identifier int, imageKeymap map[int]models.ImageData) (map[int]string, error)
}

type S3BucketRepository struct {
	s3Client         *s3.Client
	cloudfrontSigner *sign.URLSigner
	bucketName       string
	cdnBaseURL       string
	environment      string
}

func NewS3BucketRepository(s3Client *s3.Client, signer *sign.URLSigner) *S3BucketRepository {
	return &S3BucketRepository{
		s3Client:         s3Client,
		cloudfrontSigner: signer,
		bucketName:       "splajompy-bucket",
		cdnBaseURL:       os.Getenv("CLOUDFRONT_BASE_URL"),
		environment:      os.Getenv("ENVIRONMENT"),
	}
}

func (r *S3BucketRepository) CopyObject(ctx context.Context, sourceKey, destinationKey string) error {
	_, err := r.s3Client.CopyObject(ctx, &s3.CopyObjectInput{
		Bucket:     aws.String(r.bucketName),
		CopySource: aws.String(r.bucketName + "/" + sourceKey),
		Key:        aws.String(destinationKey),
	})

	return err
}

func (r *S3BucketRepository) DeleteObject(ctx context.Context, key string) error {
	_, err := r.s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(r.bucketName),
		Key:    &key,
	})

	return err
}

func (r *S3BucketRepository) DeleteObjects(ctx context.Context, keys []string) error {
	if len(keys) == 0 {
		return nil
	}

	// S3 allows up to 1000 objects per delete request
	const batchSize = 1000

	for i := 0; i < len(keys); i += batchSize {
		end := min(i+batchSize, len(keys))

		batch := keys[i:end]
		var objectsToDelete []types.ObjectIdentifier

		for _, key := range batch {
			objectsToDelete = append(objectsToDelete, types.ObjectIdentifier{
				Key: aws.String(key),
			})
		}

		_, err := r.s3Client.DeleteObjects(ctx, &s3.DeleteObjectsInput{
			Bucket: aws.String(r.bucketName),
			Delete: &types.Delete{
				Objects: objectsToDelete,
				Quiet:   aws.Bool(true), // Don't return info about successful deletions
			},
		})

		if err != nil {
			return fmt.Errorf("failed to delete batch of objects: %w", err)
		}
	}

	return nil
}

// GetPresignedPutObject returns a URL allowing a user to upload a file to a specified location
func (r *S3BucketRepository) GetPresignedPutObject(ctx context.Context, userID int, extension string, folder string) (string, string, error) {
	presignClient := s3.NewPresignClient(r.s3Client)

	blobPath := fmt.Sprintf("%s/posts/staging/%d/%s/%s.%s", r.environment, userID, folder, uuid.New(), extension)

	req, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(r.bucketName),
		Key:         aws.String(blobPath),
		ContentType: &extension,
	}, func(opts *s3.PresignOptions) {
		opts.Expires = time.Minute * 5
	})

	if err != nil {
		slog.ErrorContext(ctx, "unable to generate a signed url", "error", err)
		return "", "", err
	}

	return blobPath, req.URL, nil
}

func (r *S3BucketRepository) GetPresignedGetObject(ctx context.Context, key string) (string, error) {
	path := "https://" + r.cdnBaseURL + "/" + key

	url, err := r.cloudfrontSigner.Sign(path, time.Now().UTC().Add(time.Hour))
	if err != nil {
		slog.ErrorContext(ctx, "unable to sign cloudfront url", "error", err)
		return "", err
	}

	return url, nil
}

// GetDestinationKey returns a permenant blob URI given the current URI of a staged blob.
// An example blob URI might be production/{userId}/comment/{comment_id}/{fileName}.jpg
func GetDestinationKey(userId int, blobType string, identifier int, stagedBlobUrl string) string {
	environment := os.Getenv("ENVIRONMENT")
	filename := stagedBlobUrl[strings.LastIndex(stagedBlobUrl, "/")+1:]

	return fmt.Sprintf("%s/%d/%s/%d/%s", environment, userId, blobType, identifier, filename)
}

func (s *S3BucketRepository) PublishStagedImages(ctx context.Context, userId int, blobType string, identifier int, imageKeymap map[int]models.ImageData) (map[int]string, error) {
	destinationKeys := make(map[int]string, len(imageKeymap))

	for key, imageData := range imageKeymap {
		destinationKey := GetDestinationKey(
			userId,
			blobType,
			identifier,
			imageData.S3Key,
		)

		err := s.CopyObject(ctx, imageData.S3Key, destinationKey)
		if err != nil {
			return nil, err
		}

		err = s.DeleteObject(ctx, imageData.S3Key)
		if err != nil {
			return nil, err
		}

		destinationKeys[key] = destinationKey
	}

	return destinationKeys, nil
}
