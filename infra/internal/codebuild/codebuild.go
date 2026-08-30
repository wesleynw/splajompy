package codebuild

import (
	"github.com/pulumi/pulumi-aws/sdk/v7/go/aws/codebuild"
	"github.com/pulumi/pulumi-aws/sdk/v7/go/aws/codestarconnections"
	"github.com/pulumi/pulumi-aws/sdk/v7/go/aws/iam"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

const buildspec = `version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $REPOSITORY_URL
      - IMAGE_TAG=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c1-8)
  build:
    commands:
      - echo Build started on $(date)
      - echo Building the Docker image...
      - docker build -f api/Dockerfile -t $REPOSITORY_URL:latest -t $REPOSITORY_URL:$IMAGE_TAG api
  post_build:
    commands:
      - echo Build completed on $(date)
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URL:latest
      - docker push $REPOSITORY_URL:$IMAGE_TAG
`

var awsTags = pulumi.StringMap{
	"Project":     pulumi.String("splajompy"),
	"Environment": pulumi.String("production"),
	"ManagedBy":   pulumi.String("pulumi"),
}

func CreateImageBuildProject(ctx *pulumi.Context, repositoryUrl pulumi.StringOutput, repositoryArn pulumi.StringOutput) error {
	githubConnection, err := codestarconnections.NewConnection(ctx, "splajompy-github-connection", &codestarconnections.ConnectionArgs{
		Name:         pulumi.String("splajompy-github-connection"),
		ProviderType: pulumi.String("GitHub"),
		Tags:         awsTags,
	})
	if err != nil {
		return err
	}

	role, err := iam.NewRole(ctx, "splajompy-codebuild-role", &iam.RoleArgs{
		Name: pulumi.String("splajompy-codebuild-role"),
		AssumeRolePolicy: pulumi.String(`{
			"Version": "2012-10-17",
			"Statement": [{
				"Effect": "Allow",
				"Principal": {"Service": "codebuild.amazonaws.com"},
				"Action": "sts:AssumeRole"
			}]
		}`),
		Tags: awsTags,
	})
	if err != nil {
		return err
	}

	rolePolicy := iam.GetPolicyDocumentOutput(ctx, iam.GetPolicyDocumentOutputArgs{
		Statements: iam.GetPolicyDocumentStatementArray{
			&iam.GetPolicyDocumentStatementArgs{
				Effect: pulumi.String("Allow"),
				Actions: pulumi.StringArray{
					pulumi.String("logs:CreateLogGroup"),
					pulumi.String("logs:CreateLogStream"),
					pulumi.String("logs:PutLogEvents"),
				},
				Resources: pulumi.StringArray{
					pulumi.String("*"),
				},
			},
			&iam.GetPolicyDocumentStatementArgs{
				Effect: pulumi.String("Allow"),
				Actions: pulumi.StringArray{
					pulumi.String("ecr:GetAuthorizationToken"),
				},
				Resources: pulumi.StringArray{
					pulumi.String("*"),
				},
			},
			&iam.GetPolicyDocumentStatementArgs{
				Effect: pulumi.String("Allow"),
				Actions: pulumi.StringArray{
					pulumi.String("ecr:BatchCheckLayerAvailability"),
					pulumi.String("ecr:GetDownloadUrlForLayer"),
					pulumi.String("ecr:BatchGetImage"),
					pulumi.String("ecr:PutImage"),
					pulumi.String("ecr:InitiateLayerUpload"),
					pulumi.String("ecr:UploadLayerPart"),
					pulumi.String("ecr:CompleteLayerUpload"),
				},
				Resources: pulumi.StringArray{
					repositoryArn,
				},
			},
			&iam.GetPolicyDocumentStatementArgs{
				Effect: pulumi.String("Allow"),
				Actions: pulumi.StringArray{
					pulumi.String("codeconnections:GetConnectionToken"),
					pulumi.String("codeconnections:GetConnection"),
				},
				Resources: pulumi.StringArray{
					githubConnection.Arn,
				},
			},
		},
	})

	_, err = iam.NewRolePolicy(ctx, "splajompy-codebuild-role-policy", &iam.RolePolicyArgs{
		Role:   role.Name,
		Policy: rolePolicy.Json(),
	})
	if err != nil {
		return err
	}

	sourceCredential, err := codebuild.NewSourceCredential(ctx, "splajompy-github-credential", &codebuild.SourceCredentialArgs{
		AuthType:   pulumi.String("CODECONNECTIONS"),
		ServerType: pulumi.String("GITHUB"),
		Token:      githubConnection.Arn,
	})
	if err != nil {
		return err
	}

	project, err := codebuild.NewProject(ctx, "splajompy-api-image-build", &codebuild.ProjectArgs{
		Name:        pulumi.String("splajompy-api-image-build"),
		Description: pulumi.String("Builds api/Dockerfile and pushes the image to ECR"),
		ServiceRole: role.Arn,
		Artifacts: &codebuild.ProjectArtifactsArgs{
			Type: pulumi.String("NO_ARTIFACTS"),
		},
		BuildTimeout:  pulumi.IntPtr(5),
		QueuedTimeout: pulumi.IntPtr(5),
		Environment: &codebuild.ProjectEnvironmentArgs{
			ComputeType: pulumi.String("BUILD_GENERAL1_SMALL"),
			Image:       pulumi.String("aws/codebuild/amazonlinux-x86_64-standard:6.0"),
			Type:        pulumi.String("LINUX_CONTAINER"),
			EnvironmentVariables: codebuild.ProjectEnvironmentEnvironmentVariableArray{
				&codebuild.ProjectEnvironmentEnvironmentVariableArgs{
					Name:  pulumi.String("REPOSITORY_URL"),
					Value: repositoryUrl,
				},
			},
		},
		Source: &codebuild.ProjectSourceArgs{
			Type:              pulumi.String("GITHUB"),
			Location:          pulumi.String("https://github.com/wesleynw/splajompy.git"),
			Buildspec:         pulumi.String(buildspec),
			ReportBuildStatus: pulumi.Bool(true),
		},
		Tags: awsTags,
	}, pulumi.DependsOn([]pulumi.Resource{sourceCredential}))
	if err != nil {
		return err
	}

	ctx.Export("asdf", project.Name)

	// _, err = codebuild.NewWebhook(ctx, "splajompy-api-image-build-webhook", &codebuild.WebhookArgs{
	// 	ProjectName: project.Name,
	// 	BuildType:   pulumi.String("BUILD"),
	// 	FilterGroups: codebuild.WebhookFilterGroupArray{
	// 		&codebuild.WebhookFilterGroupArgs{
	// 			Filters: codebuild.WebhookFilterGroupFilterArray{
	// 				&codebuild.WebhookFilterGroupFilterArgs{
	// 					Type:    pulumi.String("EVENT"),
	// 					Pattern: pulumi.String("PUSH"),
	// 				},
	// 				&codebuild.WebhookFilterGroupFilterArgs{
	// 					Type:    pulumi.String("HEAD_REF"),
	// 					Pattern: pulumi.String("^refs/heads/main$"),
	// 				},
	// 				&codebuild.WebhookFilterGroupFilterArgs{
	// 					Type:    pulumi.String("FILE_PATH"),
	// 					Pattern: pulumi.String("^api/.*"),
	// 				},
	// 			},
	// 		},
	// 	},
	// })
	// if err != nil {
	// 	return err
	// }

	return nil
}
