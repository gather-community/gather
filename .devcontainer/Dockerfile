FROM ubuntu:22.04
ARG USERNAME=gatherdev

# Ensure binding is always 0.0.0.0
# Binds the server to all IP addresses of the container, so it can be accessed from outside the container.
ENV BINDING="0.0.0.0"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive TZ=US/Eastern apt-get -y install \
  build-essential \
  ca-certificates \
  curl \
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
  sed \
  unzip \
  nano \
  software-properties-common \
  sudo \
  tzdata \
  vim \
  wget \
  zsh \
  zlib1g-dev

RUN groupadd --gid 1000 $USERNAME \
  && useradd --uid 1000 --gid 1000 -m -s /bin/bash $USERNAME \
  && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Install Oh My Zsh (unattended)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set Zsh as the default shell for the root user
# If you are using a different user, adjust the command accordingly
RUN usermod -s $(which zsh) $USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME
