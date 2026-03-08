from typing import cast

import pulumi
from pulumi_digitalocean import (
    App,
    AppSpecArgsDict,
    AppSpecDomainNameArgsDict,
    AppSpecEnvArgsDict,
    DatabaseCluster,
    DatabaseDb,
    DatabaseSlug,
    Region,
    SpacesBucket,
)

config = pulumi.Config()


def secret_env(
    key: str,
    config_key: str,
    env_type: str | None = None,
    scope: str | None = None,
) -> AppSpecEnvArgsDict:
    env: AppSpecEnvArgsDict = {
        "key": key,
        "value": config.require_secret(config_key),
    }
    if env_type:
        env["type"] = env_type
    if scope:
        env["scope"] = scope
    return env


project_id = config.require("projectId")
private_network_uuid = config.require("privateNetworkUuid")

api_service_name = config.get("apiServiceName") or "splajompy-native-api"
otel_service_name = config.get("otelServiceName") or "splajompy-api-internal-utilitie2"
api_domain = config.get("apiDomain") or "api.splajompy.com"
web_domains = cast(
    list[str],
    config.get_object("webDomains") or ["splajompy.com", "www.splajompy.com"],
)
web_domain_names = cast(
    list[AppSpecDomainNameArgsDict],
    [
        {
            "name": domain,
            "type": "PRIMARY" if index == 0 else "ALIAS",
        }
        for index, domain in enumerate(web_domains)
    ],
)

api_spec = cast(
    AppSpecArgsDict,
    {
        "alerts": [{"rule": "DEPLOYMENT_FAILED"}, {"rule": "DOMAIN_FAILED"}],
        "domain_names": [{"name": api_domain, "type": "PRIMARY"}],
        "envs": [
            secret_env("GRAFANA_CLOUD_API_KEY", "apiGrafanaCloudApiKey"),
            secret_env("GRAFANA_CLOUD_INSTANCE_ID", "apiGrafanaCloudInstanceId"),
            secret_env("GRAFANA_CLOUD_OTLP_ENDPOINT", "apiGrafanaCloudOtlpEndpoint"),
        ],
        "features": ["buildpack-stack=ubuntu-22"],
        "ingress": {
            "rules": [
                {
                    "component": {"name": api_service_name},
                    "match": {"path": {"prefix": "/"}},
                },
                {
                    "component": {"name": otel_service_name},
                    "match": {
                        "authority": {"exact": api_domain},
                        "path": {"prefix": "/otel"},
                    },
                },
            ]
        },
        "maintenance": {
            "archive": False,
            "enabled": False,
            "offline_page_url": "",
        },
        "name": "splajompy-api",
        "region": "nyc",
        "services": [
            {
                "dockerfile_path": "api/Dockerfile",
                "envs": [
                    secret_env("AWS_ACCESS_KEY_ID", "apiAwsAccessKeyId"),
                    secret_env("AWS_SECRET_ACCESS_KEY", "apiAwsSecretAccessKey"),
                    secret_env(
                        "DB_CONNECTION_STRING",
                        "apiDbConnectionString",
                        env_type="SECRET",
                        scope="RUN_TIME",
                    ),
                    secret_env("OTEL_EXPORTER_OTLP_ENDPOINT", "apiOtelExporterOtlpEndpoint"),
                    secret_env("OTEL_EXPORTER_OTLP_PROTOCOL", "apiOtelExporterOtlpProtocol"),
                    secret_env("OTEL_RESOURCE_ATTRIBUTES", "apiOtelResourceAttributes"),
                    secret_env("RESEND_API_KEY", "apiResendApiKey"),
                ],
                "github": {
                    "branch": "main",
                    "deploy_on_push": True,
                    "repo": "wesleynw/splajompy",
                },
                "http_port": 8080,
                "instance_count": 1,
                "instance_size_slug": "apps-s-1vcpu-0.5gb",
                "internal_ports": [4317, 4318],
                "name": api_service_name,
                "source_dir": "api",
            },
            {
                "dockerfile_path": "api/internal/utilities/otel/Dockerfile",
                "github": {
                    "branch": "main",
                    "deploy_on_push": True,
                    "repo": "wesleynw/splajompy",
                },
                "http_port": 4318,
                "instance_count": 1,
                "instance_size_slug": "apps-s-1vcpu-0.5gb",
                "internal_ports": [4317],
                "name": otel_service_name,
                "source_dir": "api/internal/utilities/otel",
            },
        ],
    },
)

web_spec = cast(
    AppSpecArgsDict,
    {
        "alerts": [{"rule": "DEPLOYMENT_FAILED"}, {"rule": "DOMAIN_FAILED"}],
        "domain_names": web_domain_names,
        "envs": [
            secret_env("CA_CERT", "webCaCert"),
            secret_env("ENVIRONMENT", "webEnvironment"),
            secret_env("NEXT_PUBLIC_POSTHOG_KEY", "webNextPublicPosthogKey"),
            secret_env("POSTGRES_URL", "webPostgresUrl"),
            secret_env("POSTGRES_URL_NON_POOLED", "webPostgresUrlNonPooled"),
            secret_env("RESEND_API_KEY", "webResendApiKey"),
            secret_env("SPACES_ACCESS_KEY", "webSpacesAccessKey"),
            secret_env("SPACES_SECRET_KEY", "webSpacesSecretKey"),
            secret_env("SPACE_NAME", "webSpaceName"),
            secret_env("SPACE_REGION", "webSpaceRegion"),
        ],
        "features": ["buildpack-stack=ubuntu-22"],
        "ingress": {
            "rules": [
                {
                    "component": {"name": "splajompy"},
                    "match": {"path": {"prefix": "/"}},
                }
            ]
        },
        "maintenance": {
            "archive": False,
            "enabled": False,
            "offline_page_url": "",
        },
        "name": "splajompy-app",
        "region": "nyc",
        "services": [
            {
                "http_port": 8080,
                "image": {
                    "deploy_on_pushes": [{"enabled": True}],
                    "registry": "splajompy",
                    "registry_type": "DOCR",
                    "repository": "splajompy",
                    "tag": "latest",
                },
                "instance_count": 1,
                "instance_size_slug": "apps-s-1vcpu-0.5gb",
                "name": "splajompy",
            }
        ],
    },
)

splajompy_api = App(
    "splajompy-api",
    project_id=project_id,
    spec=api_spec,
    opts=pulumi.ResourceOptions(protect=True, ignore_changes=["deploymentPerPage"]),
)

splajompy_app = App(
    "splajompy-app",
    project_id=project_id,
    spec=web_spec,
    opts=pulumi.ResourceOptions(protect=True, ignore_changes=["deploymentPerPage"]),
)

splajompy_cluster = DatabaseCluster(
    "splajompy-cluster",
    engine="pg",
    name="splajompy-cluster",
    node_count=1,
    private_network_uuid=private_network_uuid,
    project_id=project_id,
    region=Region.NYC3,
    size=DatabaseSlug.D_B_1_VPCU1_GB,
    storage_size_mib="10240",
    version="18",
    opts=pulumi.ResourceOptions(protect=True),
)

splajompy_dev_db = DatabaseDb(
    "splajompy-dev-db",
    cluster_id=splajompy_cluster.id,
    name="splajompy-dev",
    opts=pulumi.ResourceOptions(protect=True),
)

splajompy_prod_db = DatabaseDb(
    "splajompy-prod-db",
    cluster_id=splajompy_cluster.id,
    name="splajompy-prod",
    opts=pulumi.ResourceOptions(protect=True),
)

splajompy_bucket = SpacesBucket(
    "splajompy-bucket",
    name="splajompy-bucket",
    region="nyc3",
    acl="private",
    opts=pulumi.ResourceOptions(protect=True),
)
