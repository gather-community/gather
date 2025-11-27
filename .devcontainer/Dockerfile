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
  zlib1g-dev

# Create user
RUN groupadd --gid 1000 $USERNAME \
  && useradd --uid 1000 --gid 1000 -m -s /bin/bash $USERNAME \
  && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to user for mise installation
USER $USERNAME
WORKDIR /home/$USERNAME

RUN curl https://mise.run | sh

# Copy mise.toml and install tools
COPY --chown=$USERNAME:$USERNAME mise.toml /tmp/mise.toml
RUN /home/$USERNAME/.local/bin/mise trust --yes /tmp/mise.toml \
  && /home/$USERNAME/.local/bin/mise install --yes -C /tmp

# Set PATH for mise
ENV PATH="/home/$USERNAME/.local/bin:/home/$USERNAME/.local/share/mise/shims:$PATH"

# Install starship
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y
RUN echo 'eval "$(starship init bash)"' >> /home/$USERNAME/.bashrc

# Copy starship config
RUN mkdir -p /home/$USERNAME/.config
COPY --chown=$USERNAME:$USERNAME .devcontainer/starship.toml /home/$USERNAME/.config/starship.toml
