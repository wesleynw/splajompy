package fakes

import (
	"context"
	"errors"
	"fmt"
	"github.com/google/uuid"
	"net/url"
	"strings"
	"sync"
	"time"
)

type FakeBucketRepository struct {
	objects       map[string][]byte
	presignedURLs map[string]string
	cdnBaseURL    string
	environment   string
	mutex         sync.RWMutex
}

func NewFakeBucketRepository() *FakeBucketRepository {
	return &FakeBucketRepository{
		objects:       make(map[string][]byte),
		presignedURLs: make(map[string]string),
		cdnBaseURL:    "https://fake-cdn.splajompy.com/",
		environment:   "test",
	}
}

func (r *FakeBucketRepository) CopyObject(ctx context.Context, sourceKey, destinationKey string) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	data, exists := r.objects[sourceKey]
	if !exists {
		return errors.New("source object does not exist")
	}

	r.objects[destinationKey] = data
	return nil
}

func (r *FakeBucketRepository) DeleteObject(ctx context.Context, key string) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if _, exists := r.objects[key]; !exists {
		return errors.New("object does not exist")
	}

	delete(r.objects, key)
	return nil
}

func (r *FakeBucketRepository) DeleteObjects(ctx context.Context, keys []string) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	for _, key := range keys {
		delete(r.objects, key)
	}
	return nil
}

func (r *FakeBucketRepository) GeneratePresignedURL(ctx context.Context, userID int, extension, folder *string) (string, string, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if extension == nil {
		return "", "", errors.New("extension cannot be nil")
	}

	if folder == nil {
		defaultFolder := "default"
		folder = &defaultFolder
	}

	s3Key := fmt.Sprintf("%s/posts/staging/%d/%s/%s.%s", r.environment, userID, *folder, uuid.New(), *extension)

	// Create a fake presigned URL
	presignedURL := fmt.Sprintf("https://fake-presigned.splajompy.com/%s?expires=%d&signature=fake",
		url.QueryEscape(s3Key),
		time.Now().Add(5*time.Minute).Unix())

	r.presignedURLs[s3Key] = presignedURL

	return s3Key, presignedURL, nil
}

func (r *FakeBucketRepository) GetObjectURL(key string) string {
	return r.cdnBaseURL + key
}

// Helper methods specific to the fake implementation

func (r *FakeBucketRepository) SetObject(key string, data []byte) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.objects[key] = data
}

func (r *FakeBucketRepository) GetObject(key string) ([]byte, bool) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	data, exists := r.objects[key]
	return data, exists
}

func (r *FakeBucketRepository) ListObjects() []string {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	keys := make([]string, 0, len(r.objects))
	for key := range r.objects {
		keys = append(keys, key)
	}

	return keys
}

func (r *FakeBucketRepository) SetEnvironment(env string) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.environment = env
}

func (r *FakeBucketRepository) SetCDNBaseURL(url string) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.cdnBaseURL = url
}

func GetDestinationKey(environment string, userID, postID int32, sourceKey string) string {
	filename := sourceKey[strings.LastIndex(sourceKey, "/"):]
	return fmt.Sprintf("%s/posts/%d/%d%s", environment, userID, postID, filename)
}
