FROM ubuntu:22.04
ARG NODE_VERSION=18.12.1
ARG RUBY_VERSION=3.2.2
ARG USERNAME=gatherdev

RUN apt-get update \
    && apt-get -y install ca-certificates curl \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install system dependencies
# Add all of your other tools here
RUN apt-get update \
  && apt-get -y install \
  build-essential \
  ca-certificates \
  containerd.io \
  curl \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin \
  git \
  gnupg \
  htop \
  iftop \
  iproute2 \
  libcurl4-openssl-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxslt1-dev \
  libxss1 \
  libyaml-dev \
  libvips \
  libvips-dev \
  make \
  pkg-config \
  python3 \
  python3-pip \
  sed \
  unzip \
  nano \
  nodejs \
  software-properties-common \
  sqlite3 \
  sudo \
  tmux \
  vim \
  wget \
  yarn \
  zlib1g-dev \
  zsh \
  && rm -rf /var/lib/apt/lists/*
  


RUN python3 -m pip install pip -U

# Install rbenv and ruby-build
RUN git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv \
    && git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build \
    && /usr/local/rbenv/plugins/ruby-build/install.sh

# Add rbenv to PATH
ENV RBENV_ROOT="/usr/local/rbenv"
ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

# Install Ruby using rbenv
RUN eval "$(rbenv init -)" && rbenv install ${RUBY_VERSION} && rbenv global ${RUBY_VERSION}

# Install bundler
RUN eval "$(rbenv init -)" && gem install bundler

# install mailcatcher
RUN eval "$(rbenv init -)" && gem install mailcatcher

# Install nvm and node
ENV NVM_DIR=/usr/local/nvm
RUN mkdir $NVM_DIR \
  && wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash \
  && . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION} \
  && . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION} \
  && . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH=/usr/local/nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}

# Install yarn
RUN npm install -g yarn


RUN groupadd --gid 1000 $USERNAME \
    && useradd --uid 1000 --gid 1000 -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME
