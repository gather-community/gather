# shellcheck shell=bash
# Service configuration (PostgreSQL, Redis, Elasticsearch, Mailcatcher)

collect_postgres_config() {
  clear_screen
  header "PostgreSQL"
  echo

  # Read existing config for defaults
  read_pg_config

  local source
  local default_source="Run in a container"
  [[ "$PG_SOURCE" == "existing" ]] && default_source="Use an existing instance"

  source="$(gum choose --header "Source:" --selected="$default_source" "Use an existing instance" "Run in a container")"

  if [[ "$source" == "Use an existing instance" ]]; then
    PG_SOURCE="existing"
    PG_HOST="$(gum input --value "${PG_HOST:-localhost}" --placeholder "Host")"
    PG_PORT="$(gum input --value "${PG_PORT:-5432}" --placeholder "Port")"
    PG_USER="$(gum input --value "$PG_USER" --placeholder "Username (blank for default)")"
    PG_PASSWORD="$(gum input --value "$PG_PASSWORD" --placeholder "Password (blank for none)")"
  else
    PG_SOURCE="docker"
    PG_HOST="postgres"
    PG_PORT="${PG_PORT:-5432}"
    PG_USER="$(gum input --value "${PG_USER:-gather}" --placeholder "Username")"
    PG_PASSWORD="$(gum input --value "${PG_PASSWORD:-gather}" --placeholder "Password")"
  fi

  # Write config
  write_pg_config
  update_compose_postgres

  msg_success "PostgreSQL configuration saved!"
  sleep 1
}

collect_redis_config() {
  clear_screen
  header "Redis"
  echo

  # Read existing config for defaults
  read_redis_config

  local source
  local default_source="Run in a container"
  [[ "$REDIS_SOURCE" == "existing" ]] && default_source="Use an existing instance"

  source="$(gum choose --header "Source:" --selected="$default_source" "Use an existing instance" "Run in a container")"

  if [[ "$source" == "Use an existing instance" ]]; then
    REDIS_SOURCE="existing"
    REDIS_HOST="$(gum input --value "${REDIS_HOST:-localhost}" --placeholder "Host")"
    REDIS_PORT="$(gum input --value "${REDIS_PORT:-6379}" --placeholder "Port")"
  else
    REDIS_SOURCE="docker"
    REDIS_HOST="redis"
    REDIS_PORT="${REDIS_PORT:-6379}"
    msg_success "Redis will run in Docker"
  fi

  # Write config
  write_redis_config
  update_compose_redis

  msg_success "Redis configuration saved!"
  sleep 1
}

collect_elasticsearch_config() {
  clear_screen
  header "Elasticsearch"
  echo

  # Read existing config for defaults
  read_es_config

  local source
  local default_source="Run in a container"
  [[ "$ES_SOURCE" == "existing" ]] && default_source="Use an existing instance"

  source="$(gum choose --header "Source:" --selected="$default_source" "Use an existing instance" "Run in a container")"

  if [[ "$source" == "Use an existing instance" ]]; then
    ES_SOURCE="existing"
    ES_HOST="$(gum input --value "${ES_HOST:-localhost}" --placeholder "Host")"
    ES_PORT="$(gum input --value "${ES_PORT:-9200}" --placeholder "Port")"
  else
    ES_SOURCE="docker"
    ES_HOST="elasticsearch"
    ES_PORT="${ES_PORT:-9200}"
    msg_success "Elasticsearch will run in Docker"
  fi

  # Write config
  write_es_config
  update_compose_elasticsearch

  msg_success "Elasticsearch configuration saved!"
  sleep 1
}

collect_oauth_config() {
  clear_screen
  header "Google OAuth"
  echo

  # Read existing config for defaults
  read_oauth_config

  if oauth_configured; then
    msg_success "OAuth credentials already configured."
    echo
    echo "  Client ID: ${GOOGLE_CLIENT_ID:0:20}..."
    echo
    if gum confirm "Keep existing credentials?"; then
      return
    fi
  fi

  echo "Create an OAuth client at: https://console.cloud.google.com/apis/credentials"
  echo
  echo "Configure with:"
  echo "  Authorized JS origins:    https://gatherdev.org:3000"
  echo "  Authorized redirect URIs: https://gatherdev.org:3000/people/users/auth/google_oauth2/callback"
  echo

  GOOGLE_CLIENT_ID="$(gum input --value "$GOOGLE_CLIENT_ID" --placeholder "Client ID")"
  GOOGLE_CLIENT_SECRET="$(gum input --value "$GOOGLE_CLIENT_SECRET" --placeholder "Client Secret")"
  echo

  if [[ -z "$GOOGLE_CLIENT_ID" || -z "$GOOGLE_CLIENT_SECRET" ]]; then
    msg_warn "OAuth credentials not provided - you'll need to add them manually later"
  else
    # Write config
    write_oauth_config
    msg_success "OAuth configuration saved!"
  fi

  sleep 1
}

collect_admin_config() {
  clear_screen
  header "Admin User"
  echo

  echo "Enter details for the initial admin user:"
  echo

  ADMIN_FNAME="$(gum input --value "$ADMIN_FNAME" --placeholder "First name")"
  ADMIN_LNAME="$(gum input --value "$ADMIN_LNAME" --placeholder "Last name")"
  ADMIN_EMAIL="$(gum input --value "$ADMIN_EMAIL" --placeholder "Email")"
}

configure_secret_key() {
  if secret_key_configured; then
    read_secret_key
    msg_success "Secret key already configured."
  else
    write_secret_key
    msg_success "Secret key generated and saved!"
  fi
}
