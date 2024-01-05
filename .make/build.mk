build-dev:
	@DOCKER_BUILDKIT=1 docker build \
    		-f Dockerfile \
    		--build-arg GITLAB_API_USER=${GITLAB_API_USER} \
    		--build-arg GITLAB_API_TOKEN=${GITLAB_API_TOKEN} \
    		--tag ${CATALOG_IMAGE}:dev .