COMPOSE_ENV = ".env.local"

data-up:
	docker compose --profile data -f deploy/docker/compose.yml up -d --remove-orphans

data-down:
	docker compose --profile data -f deploy/docker/compose.yml down --remove-orphans

data-destroy:
	docker compose --profile data -f deploy/docker/compose.yml down --volumes

delayed-up:
	docker compose --profile delayed -f deploy/docker/compose.yml up -d --remove-orphans

delayed-down:
	docker compose --profile delayed -f deploy/docker/compose.yml down --remove-orphans

gather-up:
	docker compose --profile gather -f deploy/docker/compose.yml up -d --remove-orphans

gather-down:
	docker compose --profile gather -f deploy/docker/compose.yml down --remove-orphans

init-dev:
	docker compose -f deploy/docker/compose.yml run provision

migrate-dev:
	docker compose -f deploy/docker/compose.yml run gather rake db:migrate


.PHONY: data-up data-down data-destroy init-dev migrate-dev delayed-up delayed-down gather-up gather-down