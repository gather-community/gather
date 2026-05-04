#!/bin/bash
set -e

sudo chown -R "$(whoami)" /home/"$(whoami)"/.claude
mise trust --yes

# Start the Selenium container sharing this container's network namespace so
# *.gatherdev.org wildcard DNS resolves correctly for system specs.
docker rm -f gather-selenium 2>/dev/null || true
docker run -d \
  --name gather-selenium \
  --network container:"$(hostname)" \
  --shm-size=2g \
  seleniarm/standalone-chromium:latest || true
