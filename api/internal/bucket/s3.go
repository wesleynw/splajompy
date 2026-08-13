package bucket

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go/tracing/smithyoteltracing"
	"go.opentelemetry.io/otel"
)

func NewS3Client() (*s3.Client, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("us-east-2"))
	if err != nil {
		return nil, fmt.Errorf("unable to load AWS SDK config: %v", err)
	}

	s3Client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.TracerProvider = smithyoteltracing.Adapt(otel.GetTracerProvider())
	})

	return s3Client, nil
}
