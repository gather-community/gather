#!/bin/bash
set -e

sudo chown -R "$(whoami)" /home/"$(whoami)"/.claude
mise trust --yes

# Start the Selenium container sharing this container's network namespace so
# *.gatherdev.org wildcard DNS resolves correctly for system specs.
SELENIUM_NAME="$(hostname)-selenium"
docker rm -f "$SELENIUM_NAME" 2>/dev/null || true
docker run -d \
  --name "$SELENIUM_NAME" \
  --network container:"$(hostname)" \
  --shm-size=2g \
  seleniarm/standalone-chromium:latest || true
