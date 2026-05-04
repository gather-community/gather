#!/bin/bash
set -e

mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts

mise trust --yes
sudo chown -R "$(whoami)" /bundle
gem install bundler
bundle install
yarn install

# Install gh-token helper so `gh` auto-authenticates via GitHub App credentials
sudo cp bin/gh-token /usr/local/bin/gh-token
# shellcheck disable=SC2016
GH_WRAPPER='gh() { GH_TOKEN=$(gh-token) command gh "$@"; }'
grep -qF 'gh-token' ~/.zshrc  || echo "$GH_WRAPPER" >> ~/.zshrc
grep -qF 'gh-token' ~/.bashrc || echo "$GH_WRAPPER" >> ~/.bashrc
