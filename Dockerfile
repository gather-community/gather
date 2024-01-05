ARG RUBY_VERSION=3.2.2
FROM ruby:$RUBY_VERSION

SHELL ["/bin/bash", "--login", "-c"]

# System deps -- libvps etc
RUN apt-get update -qq && \
    apt-get install -y build-essential libvips && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

WORKDIR /opt/gather

# Install NVM
# Copy nvmrc so we're always selecting the right node version
COPY .nvmrc .
# Fetch NVM Install script
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
RUN nvm install

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs=8

# At this point, we assume you have your settings.local.yml sorted 