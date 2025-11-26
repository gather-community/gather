# shellcheck shell=bash
# Config file read/write operations using yq

DATABASE_YML="$ROOT_DIR/config/database.yml"
SETTINGS_YML="$ROOT_DIR/config/settings.local.yml"
COMPOSE_YML="$ROOT_DIR/docker-compose.yml"

# -----------------------------------------------------------------------------
# Generic yq helpers
# -----------------------------------------------------------------------------
yq_read() {
  local file="$1"
  local path="$2"
  local default="${3:-}"

  if [[ ! -f "$file" ]]; then
    echo "$default"
    return
  fi

  local value
  value="$(yq -r "$path // \"\"" "$file" 2>/dev/null || echo "")"

  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

yq_write() {
  local file="$1"
  local path="$2"
  local value="$3"

  yq -i "$path = \"$value\"" "$file"
}

yq_write_int() {
  local file="$1"
  local path="$2"
  local value="$3"

  yq -i "$path = $value" "$file"
}

yq_delete() {
  local file="$1"
  local path="$2"

  yq -i "del($path)" "$file"
}

yq_has_value() {
  local file="$1"
  local path="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  local value
  value="$(yq -r "$path // \"\"" "$file" 2>/dev/null || echo "")"

  [[ -n "$value" && "$value" != "null" && "$value" != "REPLACE_ME" ]]
}

# -----------------------------------------------------------------------------
# Ensure config files exist (copy from templates)
# -----------------------------------------------------------------------------
TEMPLATES_DIR="$ROOT_DIR/config/templates"

ensure_database_yml() {
  if [[ ! -f "$DATABASE_YML" ]]; then
    cp "$TEMPLATES_DIR/database.yml" "$DATABASE_YML"
  fi
}

ensure_settings_yml() {
  if [[ ! -f "$SETTINGS_YML" ]]; then
    cp "$TEMPLATES_DIR/settings.local.yml" "$SETTINGS_YML"
  fi
}

ensure_compose_yml() {
  if [[ ! -f "$COMPOSE_YML" ]]; then
    cp "$TEMPLATES_DIR/docker-compose.yml" "$COMPOSE_YML"
  fi
}

ensure_config_files() {
  ensure_database_yml
  ensure_settings_yml
  ensure_compose_yml
}

# -----------------------------------------------------------------------------
# PostgreSQL config (database.yml)
# -----------------------------------------------------------------------------
read_pg_config() {
  PG_HOST="$(yq_read "$DATABASE_YML" '.default.host' '')"
  PG_PORT="$(yq_read "$DATABASE_YML" '.default.port' '5432')"
  PG_USER="$(yq_read "$DATABASE_YML" '.default.username' '')"
  PG_PASSWORD="$(yq_read "$DATABASE_YML" '.default.password' '')"

  # Determine source based on host
  if [[ "$PG_HOST" == "postgres" ]]; then
    PG_SOURCE="docker"
  elif [[ -n "$PG_HOST" ]]; then
    PG_SOURCE="existing"
  else
    PG_SOURCE=""
  fi
}

write_pg_config() {
  ensure_database_yml

  yq_write "$DATABASE_YML" '.default.host' "$PG_HOST"
  yq_write_int "$DATABASE_YML" '.default.port' "$PG_PORT"

  if [[ -n "$PG_USER" ]]; then
    yq_write "$DATABASE_YML" '.default.username' "$PG_USER"
  else
    yq_delete "$DATABASE_YML" '.default.username'
  fi

  if [[ -n "$PG_PASSWORD" ]]; then
    yq_write "$DATABASE_YML" '.default.password' "$PG_PASSWORD"
  else
    yq_delete "$DATABASE_YML" '.default.password'
  fi
}

pg_configured() {
  yq_has_value "$DATABASE_YML" '.default.host'
}

pg_status_text() {
  if pg_configured; then
    local host port
    host="$(yq_read "$DATABASE_YML" '.default.host' '')"
    port="$(yq_read "$DATABASE_YML" '.default.port' '5432')"
    echo "$host:$port"
  else
    echo "not configured"
  fi
}

# -----------------------------------------------------------------------------
# Redis config (settings.local.yml)
# -----------------------------------------------------------------------------
read_redis_config() {
  local url
  url="$(yq_read "$SETTINGS_YML" '.redis.url' '')"

  if [[ -n "$url" ]]; then
    # Parse redis://host:port/db
    REDIS_HOST="$(echo "$url" | sed -n 's|redis://\([^:]*\):.*|\1|p')"
    REDIS_PORT="$(echo "$url" | sed -n 's|redis://[^:]*:\([0-9]*\)/.*|\1|p')"

    if [[ "$REDIS_HOST" == "redis" ]]; then
      REDIS_SOURCE="docker"
    else
      REDIS_SOURCE="existing"
    fi
  else
    REDIS_HOST=""
    REDIS_PORT="6379"
    REDIS_SOURCE=""
  fi
}

write_redis_config() {
  ensure_settings_yml
  yq_write "$SETTINGS_YML" '.redis.url' "redis://$REDIS_HOST:$REDIS_PORT/0"
}

redis_configured() {
  yq_has_value "$SETTINGS_YML" '.redis.url'
}

redis_status_text() {
  if redis_configured; then
    yq_read "$SETTINGS_YML" '.redis.url' ''
  else
    echo "not configured"
  fi
}

# -----------------------------------------------------------------------------
# Elasticsearch config (settings.local.yml)
# -----------------------------------------------------------------------------
read_es_config() {
  ES_HOST="$(yq_read "$SETTINGS_YML" '.elasticsearch.host' '')"
  ES_PORT="$(yq_read "$SETTINGS_YML" '.elasticsearch.port' '9200')"

  if [[ "$ES_HOST" == "elasticsearch" ]]; then
    ES_SOURCE="docker"
  elif [[ -n "$ES_HOST" ]]; then
    ES_SOURCE="existing"
  else
    ES_SOURCE=""
  fi
}

write_es_config() {
  ensure_settings_yml
  yq_write "$SETTINGS_YML" '.elasticsearch.host' "$ES_HOST"
  yq_write_int "$SETTINGS_YML" '.elasticsearch.port' "$ES_PORT"
}

es_configured() {
  yq_has_value "$SETTINGS_YML" '.elasticsearch.host'
}

es_status_text() {
  if es_configured; then
    local host port
    host="$(yq_read "$SETTINGS_YML" '.elasticsearch.host' '')"
    port="$(yq_read "$SETTINGS_YML" '.elasticsearch.port' '9200')"
    echo "$host:$port"
  else
    echo "not configured"
  fi
}

# -----------------------------------------------------------------------------
# OAuth config (settings.local.yml)
# -----------------------------------------------------------------------------
read_oauth_config() {
  GOOGLE_CLIENT_ID="$(yq_read "$SETTINGS_YML" '.oauth.google.client_id' '')"
  GOOGLE_CLIENT_SECRET="$(yq_read "$SETTINGS_YML" '.oauth.google.client_secret' '')"
}

write_oauth_config() {
  ensure_settings_yml
  yq_write "$SETTINGS_YML" '.oauth.google.client_id' "$GOOGLE_CLIENT_ID"
  yq_write "$SETTINGS_YML" '.oauth.google.client_secret' "$GOOGLE_CLIENT_SECRET"
}

oauth_configured() {
  yq_has_value "$SETTINGS_YML" '.oauth.google.client_id' && \
  yq_has_value "$SETTINGS_YML" '.oauth.google.client_secret'
}

oauth_status_text() {
  if oauth_configured; then
    echo "configured"
  else
    echo "not configured"
  fi
}

# -----------------------------------------------------------------------------
# Secret key (settings.local.yml)
# -----------------------------------------------------------------------------
read_secret_key() {
  SECRET_KEY="$(yq_read "$SETTINGS_YML" '.secret_key_base' '')"
}

write_secret_key() {
  ensure_settings_yml
  if [[ -z "$SECRET_KEY" ]]; then
    SECRET_KEY="$(openssl rand -hex 64)"
  fi
  yq_write "$SETTINGS_YML" '.secret_key_base' "$SECRET_KEY"
}

secret_key_configured() {
  yq_has_value "$SETTINGS_YML" '.secret_key_base'
}

# -----------------------------------------------------------------------------
# Docker Compose management
# -----------------------------------------------------------------------------
add_compose_service() {
  local service="$1"
  local definition="$2"

  ensure_compose_yml

  # Check if service already exists
  if yq -e ".services.$service" "$COMPOSE_YML" &>/dev/null; then
    # Update existing service
    echo "$definition" | yq -i ".services.$service = load(\"/dev/stdin\")" "$COMPOSE_YML"
  else
    # Add new service
    echo "$definition" | yq -i ".services.$service = load(\"/dev/stdin\")" "$COMPOSE_YML"
  fi
}

remove_compose_service() {
  local service="$1"

  if [[ -f "$COMPOSE_YML" ]]; then
    yq -i "del(.services.$service)" "$COMPOSE_YML"
  fi
}

add_compose_volume() {
  local volume="$1"

  ensure_compose_yml
  yq -i ".volumes.$volume = {}" "$COMPOSE_YML"
}

remove_compose_volume() {
  local volume="$1"

  if [[ -f "$COMPOSE_YML" ]]; then
    yq -i "del(.volumes.$volume)" "$COMPOSE_YML"
  fi
}

update_compose_postgres() {
  if [[ "$PG_SOURCE" == "docker" ]]; then
    local definition
    definition=$(cat << EOF
image: postgres:15-alpine
environment:
  POSTGRES_USER: $PG_USER
  POSTGRES_PASSWORD: $PG_PASSWORD
  POSTGRES_DB: gather_development
ports:
  - "$PG_PORT:5432"
volumes:
  - postgres_data:/var/lib/postgresql/data
networks:
  - gather-network
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $PG_USER"]
  interval: 5s
  timeout: 5s
  retries: 5
EOF
)
    add_compose_service "postgres" "$definition"
    add_compose_volume "postgres_data"
  else
    remove_compose_service "postgres"
    remove_compose_volume "postgres_data"
  fi
}

update_compose_redis() {
  if [[ "$REDIS_SOURCE" == "docker" ]]; then
    local definition
    definition=$(cat << EOF
image: redis:7-alpine
ports:
  - "$REDIS_PORT:6379"
volumes:
  - redis_data:/data
networks:
  - gather-network
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 5s
  retries: 5
EOF
)
    add_compose_service "redis" "$definition"
    add_compose_volume "redis_data"
  else
    remove_compose_service "redis"
    remove_compose_volume "redis_data"
  fi
}

update_compose_elasticsearch() {
  if [[ "$ES_SOURCE" == "docker" ]]; then
    local definition
    definition=$(cat << EOF
image: docker.elastic.co/elasticsearch/elasticsearch:6.8.23
environment:
  - discovery.type=single-node
  - "ES_JAVA_OPTS=-Xms200m -Xmx200m"
  - xpack.security.enabled=false
ports:
  - "$ES_PORT:9200"
  - "9300:9300"
volumes:
  - elasticsearch_data:/usr/share/elasticsearch/data
networks:
  - gather-network
healthcheck:
  test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -vq '\"status\":\"red\"'"]
  interval: 10s
  timeout: 10s
  retries: 10
EOF
)
    add_compose_service "elasticsearch" "$definition"
    add_compose_volume "elasticsearch_data"
  else
    remove_compose_service "elasticsearch"
    remove_compose_volume "elasticsearch_data"
  fi
}

# -----------------------------------------------------------------------------
# Load all config from files
# -----------------------------------------------------------------------------
load_all_config() {
  read_pg_config
  read_redis_config
  read_es_config
  read_oauth_config
  read_secret_key
}
