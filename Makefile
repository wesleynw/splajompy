.PHONY: dev local local-migrate local-rollback local-seed local-notify local-stop

dev:
	pulumi env run splajompy-org/splajompy/dev -- docker compose --env-file /dev/null up --build

LOCAL_COMPOSE = docker compose --env-file /dev/null --project-name splajompy-local -f compose.yaml -f compose.local.yaml

local:
	$(MAKE) local-migrate
	$(MAKE) local-seed
	pulumi env run splajompy-org/splajompy/dev -- $(LOCAL_COMPOSE) up --build api

local-migrate:
	$(LOCAL_COMPOSE) run --rm migrate up

local-rollback:
	$(LOCAL_COMPOSE) run --rm migrate down 1

local-seed:
	$(LOCAL_COMPOSE) exec -T postgres psql -v ON_ERROR_STOP=1 -U splajompy -d splajompy-local < database/seed.sql

local-notify:
	$(LOCAL_COMPOSE) exec postgres psql -v ON_ERROR_STOP=1 -U splajompy -d splajompy-local -c "INSERT INTO notifications (user_id, message, notification_type) SELECT user_id, 'Local test notification', 'announcement' FROM users;"

local-stop:
	$(LOCAL_COMPOSE) down
