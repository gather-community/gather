#!/bin/bash

set -eo pipefail

GATHER_ARTIFACT_REGISTRY=
GATHER_RELEASE=gather
CHARTS_DIR="deploy/helm"

# Deps
helm dep up $CHARTS_DIR/gather

# Upgrade deployment and set local variables
helm upgrade -i $GATHER_RELEASE $CHARTS_DIR/gather \
    --set postgresql.primary.service.type=NodePort \
    --set-string postgresql.primary.service.nodePorts.postgresql=31000 \
    --set redis.master.service.type=NodePort \
    --set-string redis.master.service.nodePorts.redis=32000
