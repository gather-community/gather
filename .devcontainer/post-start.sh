#!/bin/bash
set -e

sudo chown -R "$(whoami)" /home/"$(whoami)"/.claude
mise trust --yes

# Start the Selenium container sharing this container's network namespace so
# *.gatherdev.org wildcard DNS resolves correctly for system specs.
#
# Capybara keeps one browser session open per driver, and specs use up to three
# (js, desktop and mobile). The node allows one session by default, so a run that
# needed a second driver waited in Selenium's queue until it timed out.
SELENIUM_NAME="$(hostname)-selenium"
docker rm -f "$SELENIUM_NAME" 2>/dev/null || true
docker run -d \
  --name "$SELENIUM_NAME" \
  --network container:"$(hostname)" \
  --shm-size=2g \
  -e SE_NODE_MAX_SESSIONS=3 \
  -e SE_NODE_OVERRIDE_MAX_SESSIONS=true \
  seleniarm/standalone-chromium:latest || true
