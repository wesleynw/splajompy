package ecr

import (
	"github.com/pulumi/pulumi-awsx/sdk/v3/go/awsx/ecr"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

func CreateImageRepository(ctx *pulumi.Context) (*ecr.Repository, error) {
	repository, err := ecr.NewRepository(ctx, "splajompy-ecr", &ecr.RepositoryArgs{
		LifecyclePolicy: &ecr.LifecyclePolicyArgs{
			Rules: ecr.LifecyclePolicyRuleArray{
				&ecr.LifecyclePolicyRuleArgs{
					Description:           pulumi.String("Keep only the 10 most recently pushed images"),
					TagStatus:             ecr.LifecycleTagStatusAny,
					MaximumNumberOfImages: pulumi.Float64(10),
				},
			},
		},
		Tags: pulumi.StringMap{
			"Project":     pulumi.String("splajompy"),
			"Environment": pulumi.String("production"),
			"ManagedBy":   pulumi.String("pulumi"),
		},
	})
	if err != nil {
		return nil, err
	}

	return repository, nil
}
