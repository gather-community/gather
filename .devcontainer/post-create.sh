#!/bin/bash
set -e

sudo chown -R "$(whoami)" ~/.ssh && chmod 700 ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts

mise trust --yes
sudo chown -R "$(whoami)" /bundle

# Gems live in a named volume that outlives the image, so a toolchain change can strand
# extensions built against something that is no longer here. The 22.04 -> 24.04 move is
# the motivating case: Ruby went from a shared libruby.so.3.2 to a static build, so every
# jammy-built .so fails to load. Fingerprint the toolchain and start the volume over
# whenever it changes, rather than making each dev wipe the volume by hand.
bundle_stamp=/bundle/.toolchain-stamp
toolchain="$(. /etc/os-release && echo "$ID$VERSION_ID")-ruby$(ruby -e \
  'print [RUBY_VERSION, RbConfig::CONFIG["ENABLE_SHARED"], RbConfig::CONFIG["host"]].join("-")')"
# An unstamped volume is treated as stale, not as fresh: volumes predating this check
# hold jammy-built gems and are exactly the ones that need clearing. On a genuinely
# empty volume the delete is a no-op.
if [ "$(cat "$bundle_stamp" 2>/dev/null)" != "$toolchain" ]; then
  echo "Gem volume was built by '$(cat "$bundle_stamp" 2>/dev/null || true)', toolchain is now" \
    "'$toolchain'; rebuilding gems from scratch."
  find /bundle -mindepth 1 -delete
fi

gem install bundler
bundle install
echo "$toolchain" > "$bundle_stamp"
yarn install

mise run setup

# Install gh-token helper so `gh` auto-authenticates via GitHub App credentials
sudo cp bin/gh-token /usr/local/bin/gh-token
# shellcheck disable=SC2016
GH_WRAPPER='gh() { GH_TOKEN=$(gh-token) command gh "$@"; }'
grep -qF 'gh-token' ~/.zshrc  || echo "$GH_WRAPPER" >> ~/.zshrc
grep -qF 'gh-token' ~/.bashrc || echo "$GH_WRAPPER" >> ~/.bashrc
