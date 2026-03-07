# Pulumi Guide

## Install

Assuming Homebrew:

```bash
brew install pulumi/tap/pulumi
brew install pulumi/tap/esc
brew install doctl
brew install uv
```

Verify:

```bash
pulumi version
esc version
doctl version
uv --version
```

Log in:

```bash
pulumi login
doctl auth init
```

## Layout

- Pulumi org: `splajompy`
- Pulumi project: `splajompy-infra`
- Infra stack: `splajompy/splajompy-infra/prod`
- Prod ESC env: `splajompy/splajompy-infra/prod`
- Dev ESC env: `splajompy/splajompy-infra/dev`

This repo uses one real infrastructure stack: `prod`.

`dev` is an ESC config overlay for local development, not a second deployed stack.

## Common commands

Run these from `infra/`.

Select the stack:

```bash
pulumi stack select splajompy/splajompy-infra/prod
```

Preview changes:

```bash
pulumi preview --stack splajompy/splajompy-infra/prod
pulumi preview --diff --stack splajompy/splajompy-infra/prod
```

Apply changes:

```bash
pulumi up --stack splajompy/splajompy-infra/prod
```

Inspect managed resources:

```bash
pulumi state ls --stack splajompy/splajompy-infra/prod
```

Refresh state:

```bash
pulumi refresh --stack splajompy/splajompy-infra/prod
```

## ESC commands

Inspect the stored environment definitions:

```bash
pulumi env get splajompy/splajompy-infra/prod '' --definition | jq
pulumi env get splajompy/splajompy-infra/dev '' --definition | jq
```

Open the resolved environments:

```bash
pulumi env open splajompy/splajompy-infra/prod --format yaml
pulumi env open splajompy/splajompy-infra/dev --format yaml
```

The `dev` environment should look like this at the definition level:

```yaml
imports:
  - splajompy-infra/prod
values:
  pulumiConfig:
    apiDbConnectionString: ...
    webPostgresUrl: ...
    webPostgresUrlNonPooled: ...
    webEnvironment: ...
```

## Checks

Run local checks before changing infra code:

```bash
uv run python -m py_compile __main__.py
uv run --group dev ty check __main__.py
uv run --group dev ruff check __main__.py
```

## Notes

- [Pulumi.prod.yaml](/Users/ajholzbach/Developer/splajompy-native/infra/Pulumi.prod.yaml#L1) is safe to commit because it only contains the ESC environment reference.
- `projectId` and `privateNetworkUuid` are identifiers, not secrets.
- Tokens, keys, certs, and connection strings belong in ESC secrets.
