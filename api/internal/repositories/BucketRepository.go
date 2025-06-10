package repositories

import (
	"context"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/google/uuid"
	"log"
	"os"
	"strings"
	"time"
)

type BucketRepository interface {
	CopyObject(ctx context.Context, sourceKey, destinationKey string) error
	DeleteObject(ctx context.Context, key string) error
	GeneratePresignedURL(ctx context.Context, userID int, extension, folder *string) (string, string, error)
	GetObjectURL(key string) string
}

type S3BucketRepository struct {
	s3Client    *s3.Client
	bucketName  string
	cdnBaseURL  string
	environment string
}

func NewS3BucketRepository(s3Client *s3.Client) *S3BucketRepository {
	return &S3BucketRepository{
		s3Client:    s3Client,
		bucketName:  "splajompy-bucket",
		cdnBaseURL:  "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/",
		environment: os.Getenv("ENVIRONMENT"),
	}
}

func (r *S3BucketRepository) CopyObject(ctx context.Context, sourceKey, destinationKey string) error {
	_, err := r.s3Client.CopyObject(ctx, &s3.CopyObjectInput{
		Bucket:     aws.String(r.bucketName),
		CopySource: aws.String(r.bucketName + "/" + sourceKey),
		Key:        aws.String(destinationKey),
		ACL:        types.ObjectCannedACLPublicRead,
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

func (r *S3BucketRepository) GeneratePresignedURL(ctx context.Context, userID int, extension, folder *string) (string, string, error) {
	presignClient := s3.NewPresignClient(r.s3Client)

	s3Key := fmt.Sprintf("%s/posts/staging/%d/%s/%s.%s", r.environment, userID, *folder, uuid.New(), *extension)

	req, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(r.bucketName),
		Key:         aws.String(s3Key),
		ContentType: extension,
		ACL:         types.ObjectCannedACLPublicRead,
	}, func(opts *s3.PresignOptions) {
		opts.Expires = time.Minute * 5
	})

	if err != nil {
		log.Printf("Couldn't get a presigned request to put. Here's why: %v\n", err)
		return "", "", err
	}

	return s3Key, req.URL, nil
}

func (r *S3BucketRepository) GetObjectURL(key string) string {
	return r.cdnBaseURL + key
}

func GetDestinationKey(environment string, userID, postID int, sourceKey string) string {
	filename := sourceKey[strings.LastIndex(sourceKey, "/"):]
	return fmt.Sprintf("%s/posts/%d/%d%s", environment, userID, postID, filename)
}
