package main

import (
	"encoding/base64"
	"encoding/json"

	"github.com/pulumi/pulumi-aws/sdk/v7/go/aws/cloudfront"
	"github.com/pulumi/pulumi-aws/sdk/v7/go/aws/iam"
	"github.com/pulumi/pulumi-aws/sdk/v7/go/aws/s3"
	"github.com/pulumi/pulumi-digitalocean/sdk/v4/go/digitalocean"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		config := config.New(ctx, "")

		domain, err := digitalocean.NewDomain(ctx, "domain", &digitalocean.DomainArgs{
			Name: pulumi.String("splajompy.com"),
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		splajompyCluster, err := digitalocean.NewDatabaseCluster(ctx, "splajompy-cluster", &digitalocean.DatabaseClusterArgs{
			Engine:             pulumi.String("pg"),
			Name:               pulumi.String("splajompy-cluster"),
			NodeCount:          pulumi.Int(1),
			PrivateNetworkUuid: pulumi.String("10bd86a3-9f00-43e5-bf18-bb521493dc8e"),
			ProjectId:          pulumi.String("f1c31037-04ff-4580-93f4-ae1d43d83a7f"),
			Region:             pulumi.String(digitalocean.RegionNYC3),
			Size:               pulumi.String(digitalocean.DatabaseSlug_DB_1VPCU1GB),
			StorageSizeMib:     pulumi.String("10240"),
			Version:            pulumi.String("18"),
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		_, err = digitalocean.NewDatabaseDb(ctx, "splajompy-prod", &digitalocean.DatabaseDbArgs{
			ClusterId: splajompyCluster.ID(),
			Name:      pulumi.String("splajompy-prod"),
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		_, err = digitalocean.NewDatabaseDb(ctx, "splajompy-dev", &digitalocean.DatabaseDbArgs{
			ClusterId: splajompyCluster.ID(),
			Name:      pulumi.String("splajompy-dev"),
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		_, err = digitalocean.NewSpacesBucket(ctx, "splajompy-bucket", &digitalocean.SpacesBucketArgs{
			Name: pulumi.String("splajompy-bucket"),
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		splajompyApp, err := digitalocean.NewApp(ctx, "splajompy-app", &digitalocean.AppArgs{
			Spec: &digitalocean.AppSpecArgs{
				Alerts: digitalocean.AppSpecAlertArray{
					&digitalocean.AppSpecAlertArgs{
						Rule: pulumi.String("DEPLOYMENT_FAILED"),
					},
					&digitalocean.AppSpecAlertArgs{
						Rule: pulumi.String("DOMAIN_FAILED"),
					},
				},
				Domains: pulumi.StringArray{
					pulumi.Sprintf("api.%s", domain.Name),
				},
				Name:   pulumi.String("splajompy-app"),
				Region: pulumi.String("nyc"),
				Ingress: &digitalocean.AppSpecIngressArgs{
					Rules: digitalocean.AppSpecIngressRuleArray{
						&digitalocean.AppSpecIngressRuleArgs{
							Component: &digitalocean.AppSpecIngressRuleComponentArgs{
								Name: pulumi.String("splajompy-api"),
							},
							Match: &digitalocean.AppSpecIngressRuleMatchArgs{
								Path: &digitalocean.AppSpecIngressRuleMatchPathArgs{
									Prefix: pulumi.String("/"),
								},
							},
						},
						&digitalocean.AppSpecIngressRuleArgs{
							Component: &digitalocean.AppSpecIngressRuleComponentArgs{
								Name: pulumi.String("splajompy-api-otel"),
							},
							Match: &digitalocean.AppSpecIngressRuleMatchArgs{
								Path: &digitalocean.AppSpecIngressRuleMatchPathArgs{
									Prefix: pulumi.String("/otel"),
								},
							},
						},
					},
				},
				Services: digitalocean.AppSpecServiceArray{
					&digitalocean.AppSpecServiceArgs{
						DockerfilePath: pulumi.String("api/Dockerfile"),
						Envs: digitalocean.AppSpecServiceEnvArray{
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("APN_KEY_ID"),
								Value: config.GetSecret("apnKeyId"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("APN_PRIVATE_KEY"),
								Value: config.GetSecret("apnPrivateKey"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("APN_TEAM_ID"),
								Value: config.GetSecret("apnTeamId"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("AWS_ACCESS_KEY_ID"),
								Value: config.GetSecret("apiAwsAccessKeyId"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("AWS_SECRET_ACCESS_KEY"),
								Value: config.GetSecret("apiAwsSecretAccessKey"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("DB_CONNECTION_STRING"),
								Value: config.GetSecret("apiDbConnectionString"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("ENVIRONMENT"),
								Value: pulumi.ToSecret("production").(pulumi.StringOutput),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("OTEL_EXPORTER_OTLP_ENDPOINT"),
								Value: pulumi.String("http://splajompy-api-otel:4318"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("OTEL_EXPORTER_OTLP_PROTOCOL"),
								Value: pulumi.ToSecret("http/protobuf").(pulumi.StringOutput),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("OTEL_RESOURCE_ATTRIBUTES"),
								Value: pulumi.ToSecret("service.name=api,service.namespace=splajompy,deployment.environment=production,service.instance.id=4d354f83-2911-4b7b-b486-076f1c8440d0").(pulumi.StringOutput),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("PYROSCOPE_PW"),
								Value: config.GetSecret("apiGrafanaCloudApiKey"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("PYROSCOPE_USER"),
								Value: pulumi.ToSecret("1325566").(pulumi.StringOutput),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("RESEND_API_KEY"),
								Value: config.GetSecret("apiResendApiKey"),
							},
						},
						Github: &digitalocean.AppSpecServiceGithubArgs{
							Branch:       pulumi.String("main"),
							DeployOnPush: pulumi.Bool(true),
							Repo:         pulumi.String("wesleynw/splajompy"),
						},
						HttpPort:         pulumi.Int(8080),
						InstanceCount:    pulumi.Int(1),
						InstanceSizeSlug: pulumi.String("apps-s-1vcpu-0.5gb"),
						Name:             pulumi.String("splajompy-api"),
						SourceDir:        pulumi.String("api"),
					},
					&digitalocean.AppSpecServiceArgs{
						DockerfilePath: pulumi.String("api/internal/utilities/otel/Dockerfile"),
						Envs: digitalocean.AppSpecServiceEnvArray{
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("GRAFANA_CLOUD_API_KEY"),
								Value: config.GetSecret("apiGrafanaCloudApiKey"),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("GRAFANA_CLOUD_INSTANCE_ID"),
								Value: pulumi.ToSecret("1325566").(pulumi.StringOutput),
							},
							&digitalocean.AppSpecServiceEnvArgs{
								Key:   pulumi.String("GRAFANA_CLOUD_OTLP_ENDPOINT"),
								Value: pulumi.ToSecret("https://otlp-gateway-prod-us-east-2.grafana.net/otlp").(pulumi.StringOutput),
							},
						},
						Github: &digitalocean.AppSpecServiceGithubArgs{
							Branch:       pulumi.String("main"),
							DeployOnPush: pulumi.Bool(true),
							Repo:         pulumi.String("wesleynw/splajompy"),
						},
						HttpPort:         pulumi.Int(4318),
						InstanceCount:    pulumi.Int(1),
						InstanceSizeSlug: pulumi.String("apps-s-1vcpu-0.5gb"),
						Name:             pulumi.String("splajompy-api-otel"),
						SourceDir:        pulumi.String("api/internal/utilities/otel"),
					},
				},
			},
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		var allowedIPs []string
		config.RequireObject("dbIPAllowlist", &allowedIPs)

		rules := digitalocean.DatabaseFirewallRuleArray{
			&digitalocean.DatabaseFirewallRuleArgs{
				Type:  pulumi.String("app"),
				Value: splajompyApp.ID(),
			},
		}

		for _, ip := range allowedIPs {
			rules = append(rules, &digitalocean.DatabaseFirewallRuleArgs{
				Type:  pulumi.String("ip_addr"),
				Value: pulumi.String(ip),
			})
		}

		_, err = digitalocean.NewDatabaseFirewall(ctx, "db-firewall", &digitalocean.DatabaseFirewallArgs{
			ClusterId: splajompyCluster.ID(),
			Rules:     rules,
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		splajompyBucket, err := s3.NewBucket(ctx, "splajompy-prod-bucket", &s3.BucketArgs{
			Bucket: pulumi.String("splajompy-prod-bucket"),
		})
		if err != nil {
			return err
		}

		user, err := iam.NewUser(ctx, "splajompy-prod-bucket-user", &iam.UserArgs{
			Name: pulumi.String("splajompy-prod-bucket-user"),
		})
		if err != nil {
			return err
		}

		policyJson := splajompyBucket.Arn.ApplyT(func(bucketArn string) (string, error) {
			json, err := json.Marshal(map[string]any{
				"Version": "2012-10-17",
				"Statement": []map[string]any{
					{
						"Sid":    "Statement0",
						"Effect": "Allow",
						"Action": "s3:*",
						"Resource": []string{
							bucketArn,
							bucketArn + "/*",
						},
					},
				},
			})
			if err != nil {
				return "", err
			}
			return string(json), nil
		})

		splajompyBucketPolicy, err := iam.NewPolicy(ctx, "splajompy-bucket-full-access", &iam.PolicyArgs{
			Name:   pulumi.String("splajompy-bucket-full-access"),
			Policy: policyJson,
		})
		if err != nil {
			return err
		}

		_, err = iam.NewPolicyAttachment(ctx, "s3-all-access", &iam.PolicyAttachmentArgs{
			Users:     pulumi.Array{user.Name},
			PolicyArn: splajompyBucketPolicy.Arn,
		})
		if err != nil {
			return err
		}

		s3AccessKey, err := iam.NewAccessKey(ctx, "s3-splajompy-prod-bucket-access-key", &iam.AccessKeyArgs{
			User: user.Name,
		})
		if err != nil {
			return err
		}

		ctx.Export("s3accesskey", s3AccessKey.ID())
		ctx.Export("s3accesssecret", s3AccessKey.Secret)

		oac, err := cloudfront.NewOriginAccessControl(ctx, "s3access", &cloudfront.OriginAccessControlArgs{
			Name:                          pulumi.String("cf-splajompy-bucket-oac"),
			OriginAccessControlOriginType: pulumi.String("s3"),
			SigningBehavior:               pulumi.String("always"),
			SigningProtocol:               pulumi.String("sigv4"),
		})
		if err != nil {
			return err
		}

		base64Key := config.GetSecret("cloudfrontSigningKey")
		pemStr := base64Key.ApplyT(func(key string) (string, error) {
			decoded, err := base64.StdEncoding.DecodeString(key)
			if err != nil {
				return "", err
			}

			return string(decoded), nil
		}).(pulumi.StringOutput)

		cfPublicKey, err := cloudfront.NewPublicKey(ctx, "cf-pubkey", &cloudfront.PublicKeyArgs{
			Name:       pulumi.String("cf-pubkey"),
			EncodedKey: pemStr,
		})
		if err != nil {
			return err
		}

		cfKeyGroup, err := cloudfront.NewKeyGroup(ctx, "cf-keygrp", &cloudfront.KeyGroupArgs{
			Name: pulumi.String("cf-keygrp"),
			Items: pulumi.StringArray{
				cfPublicKey.ID(),
			},
		})

		cloudfrontDist, err := cloudfront.NewDistribution(ctx, "splajompy-cf", &cloudfront.DistributionArgs{
			DefaultCacheBehavior: cloudfront.DistributionDefaultCacheBehaviorArgs{
				AllowedMethods: pulumi.StringArray{
					pulumi.String("GET"), pulumi.String("HEAD"),
				},
				CachedMethods: pulumi.StringArray{
					pulumi.String("GET"), pulumi.String("HEAD"),
				},
				TargetOriginId: splajompyBucket.Arn,
				// ok to hardcode
				// https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-caching-optimized
				CachePolicyId:        pulumi.String("658327ea-f89d-4fab-a63d-7e88639e58f6"),
				ViewerProtocolPolicy: pulumi.String("redirect-to-https"),
				TrustedKeyGroups: pulumi.StringArray{
					cfKeyGroup.ID(),
				},
			},
			Enabled: pulumi.Bool(true),
			Origins: cloudfront.DistributionOriginArray{
				cloudfront.DistributionOriginArgs{
					DomainName:            splajompyBucket.BucketRegionalDomainName,
					OriginId:              splajompyBucket.Arn,
					OriginAccessControlId: oac.ID(),
				},
			},
			Restrictions: cloudfront.DistributionRestrictionsArgs{
				GeoRestriction: cloudfront.DistributionRestrictionsGeoRestrictionArgs{
					RestrictionType: pulumi.String("none"),
				},
			},
			ViewerCertificate: cloudfront.DistributionViewerCertificateArgs{
				CloudfrontDefaultCertificate: pulumi.Bool(true),
			},
		})
		if err != nil {
			return err
		}

		cfBucketPolicy := pulumi.All(splajompyBucket.Arn, cloudfrontDist.Arn).ApplyT(
			func(args []any) (string, error) {
				bucketArn := args[0].(string)
				distArn := args[1].(string)

				policy, err := json.Marshal(map[string]any{
					"Version": "2012-10-17",
					"Statement": []map[string]any{
						{
							"Effect": "Allow",
							"Principal": map[string]string{
								"Service": "cloudfront.amazonaws.com",
							},
							"Action":   "s3:GetObject",
							"Resource": bucketArn + "/*",
							"Condition": map[string]any{
								"StringEquals": map[string]string{
									"AWS:SourceArn": distArn,
								},
							},
						},
					},
				})
				if err != nil {
					return "", err
				}

				return string(policy), nil
			},
		).(pulumi.StringOutput)

		_, err = s3.NewBucketPolicy(ctx, "cloudfront-s3-access", &s3.BucketPolicyArgs{
			Bucket: splajompyBucket.ID(),
			Policy: cfBucketPolicy,
		})

		return nil
	})
}
