package ecr

import (
	"github.com/pulumi/pulumi-awsx/sdk/v3/go/awsx/ecr"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

func CreateImageRepository(ctx *pulumi.Context) (*ecr.Repository, error) {
	repository, err := ecr.NewRepository(ctx, "splajompy-ecr", &ecr.RepositoryArgs{
		Tags: pulumi.StringMap{
			"Project":     pulumi.String("splajompy"),
			"Environment": pulumi.String("production"),
			"ManagedBy":   pulumi.String("pulumi"),
		},
	})
	if err != nil {
		return nil, err
	}

	_, err = ecr.NewImage(ctx, "splajompy-api", &ecr.ImageArgs{
		RepositoryUrl: repository.Url,
		Context:       pulumi.String("../api"),
		ImageName:     pulumi.String("splajompy-api-img"),
		ImageTag:      pulumi.String("latest"),
	})
	if err != nil {
		return nil, err
	}

	return repository, nil
}
