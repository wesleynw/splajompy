package service

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func NewS3Client() (*s3.Client, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("nyc3"))
	if err != nil {
		return nil, fmt.Errorf("unable to load AWS SDK config: %v", err)
	}

	s3Client := s3.NewFromConfig(cfg)

	return s3Client, nil
}
