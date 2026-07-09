package main

import (
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

		_, err = digitalocean.NewApp(ctx, "splajompy-app", &digitalocean.AppArgs{
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
				Ingress: &digitalocean.AppSpecIngressArgs{
					Rules: digitalocean.AppSpecIngressRuleArray{
						&digitalocean.AppSpecIngressRuleArgs{
							Component: &digitalocean.AppSpecIngressRuleComponentArgs{
								Name: pulumi.String("splajompy-native-api"),
							},
							Match: &digitalocean.AppSpecIngressRuleMatchArgs{
								Path: &digitalocean.AppSpecIngressRuleMatchPathArgs{
									Prefix: pulumi.String("/"),
								},
							},
						},
						&digitalocean.AppSpecIngressRuleArgs{
							Component: &digitalocean.AppSpecIngressRuleComponentArgs{
								Name: pulumi.String("splajompy-api-internal-utilitie2"),
							},
							Match: &digitalocean.AppSpecIngressRuleMatchArgs{
								Authority: &digitalocean.AppSpecIngressRuleMatchAuthorityArgs{
									Exact: pulumi.String("api.splajompy.com"),
								},
								Path: &digitalocean.AppSpecIngressRuleMatchPathArgs{
									Prefix: pulumi.String("/otel"),
								},
							},
						},
					},
				},
				Name:   pulumi.String("splajompy-api"),
				Region: pulumi.String("nyc"),
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
								Value: config.GetSecret("apiOtelExporterOtlpEndpoint"),
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
						InternalPorts: pulumi.IntArray{
							pulumi.Int(4317),
							pulumi.Int(4318),
						},
						Name:      pulumi.String("splajompy-native-api"),
						SourceDir: pulumi.String("api"),
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
						InternalPorts: pulumi.IntArray{
							pulumi.Int(4317),
						},
						Name:      pulumi.String("splajompy-api-internal-utilitie2"),
						SourceDir: pulumi.String("api/internal/utilities/otel"),
					},
				},
			},
		}, pulumi.Protect(true))
		if err != nil {
			return err
		}

		return nil
	})
}
