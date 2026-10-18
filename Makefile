.PHONY: dev

dev:
	pulumi env run splajompy-org/splajompy/dev -- docker compose --env-file /dev/null up --build
