#!/bin/sh

# The devcontainer should use the same network as the application so we can reach services by name,
# This should match the network in the compose file and runArgs in devcontainer.json

docker network create gather-network --label "com.docker.compose.network=gather" --label "com.docker.compose.project=gather" 2>/dev/null || true