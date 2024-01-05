COMPOSE_ENV = ".env.local"

data-up:
	docker compose --profile data -f deploy/docker/compose.yml up -d --remove-orphans

data-down:
	docker compose --profile data -f deploy/docker/compose.yml down --remove-orphans

data-destroy:
	docker compose --profile data -f deploy/docker/compose.yml down --volumes

.PHONY: data-up data-down data-destroy