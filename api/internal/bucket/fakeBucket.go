package bucket

import (
	"context"

	"splajompy.com/api/v2/internal/models"
)

type FakeBucketRepository struct{}

func (f *FakeBucketRepository) CopyObject(_ context.Context, _, _ string) error   { return nil }
func (f *FakeBucketRepository) DeleteObject(_ context.Context, _ string) error    { return nil }
func (f *FakeBucketRepository) DeleteObjects(_ context.Context, _ []string) error { return nil }
func (f *FakeBucketRepository) GetPresignedPutObject(_ context.Context, _ int, _, _ *string) (string, string, error) {
	return "", "", nil
}
func (f *FakeBucketRepository) GetPresignedGetObject(_ context.Context, key string) (*string, error) {
	return &key, nil
}
func (f *FakeBucketRepository) PublishStagedImages(_ context.Context, _ int, _ string, _ int, imageKeymap map[int]models.ImageData) (map[int]string, error) {
	keys := make(map[int]string, len(imageKeymap))
	for i, data := range imageKeymap {
		keys[i] = data.S3Key
	}
	return keys, nil
}
