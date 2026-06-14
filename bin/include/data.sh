# shellcheck shell=bash
# Start data services and provision database

# Module-level variables (set by _data_load_config)
_DATA_PG_HOST=""
_DATA_PG_PORT=""
_DATA_PG_USER=""
_DATA_PG_PASSWORD=""
_DATA_PG_DATABASE=""
_DATA_REDIS_URL=""
_DATA_ES_HOST=""
_DATA_ES_PORT=""

_data_yq_read() {
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

_data_load_config() {
  local database_yml="$ROOT_DIR/config/database.yml"
  local settings_yml="$ROOT_DIR/config/settings.local.yml"

  _DATA_PG_HOST="$(_data_yq_read "$database_yml" '.default.host' '')"
  _DATA_PG_PORT="$(_data_yq_read "$database_yml" '.default.port' '5432')"
  _DATA_PG_USER="$(_data_yq_read "$database_yml" '.default.username' '')"
  _DATA_PG_PASSWORD="$(_data_yq_read "$database_yml" '.default.password' '')"
  _DATA_PG_DATABASE="$(_data_yq_read "$database_yml" '.development.database' 'gather_development')"

  _DATA_REDIS_URL="$(_data_yq_read "$settings_yml" '.redis.url' '')"

  _DATA_ES_HOST="$(_data_yq_read "$settings_yml" '.elasticsearch.host' '')"
  _DATA_ES_PORT="$(_data_yq_read "$settings_yml" '.elasticsearch.port' '9200')"
}

_data_validate_config() {
  local missing=()

  [[ -z "$_DATA_PG_HOST" ]] && missing+=("PostgreSQL host")
  [[ -z "$_DATA_REDIS_URL" ]] && missing+=("Redis URL")
  [[ -z "$_DATA_ES_HOST" ]] && missing+=("Elasticsearch host")

  if [[ ${#missing[@]} -gt 0 ]]; then
    msg_error "Missing configuration:"
    for item in "${missing[@]}"; do
      echo "  - $item"
    done
    echo
    echo "Run 'bin/setup conf' to generate default configuration."
    return 1
  fi
}

_data_test_postgres() {
  if [[ -n "$_DATA_PG_PASSWORD" ]]; then
    PGPASSWORD="$_DATA_PG_PASSWORD" pg_isready -h "$_DATA_PG_HOST" -p "$_DATA_PG_PORT" -U "$_DATA_PG_USER" &>/dev/null
  else
    pg_isready -h "$_DATA_PG_HOST" -p "$_DATA_PG_PORT" ${_DATA_PG_USER:+-U "$_DATA_PG_USER"} &>/dev/null
  fi
}

_data_test_redis() {
  local redis_host redis_port
  redis_host="$(echo "$_DATA_REDIS_URL" | sed -n 's|redis://\([^:]*\):.*|\1|p')"
  redis_port="$(echo "$_DATA_REDIS_URL" | sed -n 's|redis://[^:]*:\([0-9]*\)/.*|\1|p')"
  redis-cli -h "$redis_host" -p "$redis_port" ping &>/dev/null
}

_data_test_elasticsearch() {
  curl -s "http://${_DATA_ES_HOST}:${_DATA_ES_PORT}/_cluster/health" &>/dev/null
}

_data_test_mailman() {
  # Try Docker service name (devcontainer) then localhost port mapping (host)
  curl -s --max-time 5 -u restadmin:restpass http://mailman-core:8001/3.1/system/versions &>/dev/null ||
  curl -s --max-time 5 -u restadmin:restpass http://localhost:8001/3.1/system/versions &>/dev/null
}

_data_test_all_connections() {
  local all_ok=true

  printf "  %-16s " "PostgreSQL"
  if _data_test_postgres; then
    gum style --foreground 2 "✓ connected"
  else
    gum style --foreground 1 "✗ failed"
    all_ok=false
  fi

  printf "  %-16s " "Redis"
  if _data_test_redis; then
    gum style --foreground 2 "✓ connected"
  else
    gum style --foreground 1 "✗ failed"
    all_ok=false
  fi

  printf "  %-16s " "Elasticsearch"
  if _data_test_elasticsearch; then
    gum style --foreground 2 "✓ connected"
  else
    gum style --foreground 1 "✗ failed"
    all_ok=false
  fi

  printf "  %-16s " "Mailman"
  if _data_test_mailman; then
    gum style --foreground 2 "✓ connected"
  else
    gum style --foreground 1 "✗ failed"
    all_ok=false
  fi

  [[ "$all_ok" == "true" ]]
}

_data_start_docker_services() {
  local network_name
  network_name="$(basename "$ROOT_DIR")-network"
  msg_success "==> Creating Docker network (${network_name})..."
  docker network create "$network_name" 2>/dev/null || true

  msg_success "==> Starting Docker services..."
  if ! docker compose up -d; then
    msg_error "Failed to start Docker services"
    return 1
  fi

  msg_success "==> Waiting for services to be ready..."
  local timeout=60
  local start_time=$SECONDS

  while ! _data_test_all_connections; do
    if [[ $((SECONDS - start_time)) -gt $timeout ]]; then
      msg_error "Services failed to become ready within ${timeout}s"
      return 1
    fi
    sleep 2
  done
}

_data_database_exists() {
  if [[ -n "$_DATA_PG_PASSWORD" ]]; then
    PGPASSWORD="$_DATA_PG_PASSWORD" psql -h "$_DATA_PG_HOST" -p "$_DATA_PG_PORT" -U "$_DATA_PG_USER" -d "$_DATA_PG_DATABASE" -c "SELECT 1" &>/dev/null
  else
    psql -h "$_DATA_PG_HOST" -p "$_DATA_PG_PORT" ${_DATA_PG_USER:+-U "$_DATA_PG_USER"} -d "$_DATA_PG_DATABASE" -c "SELECT 1" &>/dev/null
  fi
}

_data_get_super_admin() {
  local query="
    SELECT u.email, u.first_name, u.last_name
    FROM users u
    JOIN users_roles ur ON ur.user_id = u.id
    JOIN roles r ON r.id = ur.role_id
    WHERE r.name = 'super_admin'
    LIMIT 1
  "
  local result
  if [[ -n "$_DATA_PG_PASSWORD" ]]; then
    result="$(PGPASSWORD="$_DATA_PG_PASSWORD" psql -h "$_DATA_PG_HOST" -p "$_DATA_PG_PORT" -U "$_DATA_PG_USER" -d "$_DATA_PG_DATABASE" -t -A -F'|' -c "$query" 2>/dev/null)"
  else
    result="$(psql -h "$_DATA_PG_HOST" -p "$_DATA_PG_PORT" ${_DATA_PG_USER:+-U "$_DATA_PG_USER"} -d "$_DATA_PG_DATABASE" -t -A -F'|' -c "$query" 2>/dev/null)"
  fi
  echo "$result"
}

_data_collect_admin_config() {
  echo
  gum style --bold "Admin User"
  echo
  echo "Enter details for the initial admin user:"
  echo

  _DATA_ADMIN_FNAME="$(gum input --placeholder "First name")"
  _DATA_ADMIN_LNAME="$(gum input --placeholder "Last name")"
  _DATA_ADMIN_EMAIL="$(gum input --placeholder "Email")"
}

_data_provision_database() {
  _data_collect_admin_config
  echo

  msg_success "==> Creating database..."
  bundle exec rake db:create 2>&1 | filter_noise
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    msg_error "Failed to create database"
    return 1
  fi

  msg_success "==> Loading schema..."
  bundle exec rake db:schema:load 2>&1 | filter_noise
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    msg_error "Failed to load schema"
    return 1
  fi

  msg_success "==> Creating cluster with admin user..."
  bundle exec rake db:new_cluster \
      ADMIN_FNAME="$_DATA_ADMIN_FNAME" \
      ADMIN_LNAME="$_DATA_ADMIN_LNAME" \
      ADMIN_EMAIL="$_DATA_ADMIN_EMAIL" \
      SUPER_ADMIN=y 2>&1 | filter_noise
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    msg_error "Failed to create cluster"
    return 1
  fi

  echo
  gum style --bold --foreground 2 "Database provisioned successfully!"
}

_data_show_existing_admin() {
  local admin_info="$1"
  local email first_name last_name

  email="$(echo "$admin_info" | cut -d'|' -f1)"
  first_name="$(echo "$admin_info" | cut -d'|' -f2)"
  last_name="$(echo "$admin_info" | cut -d'|' -f3)"

  echo
  gum style --bold "Existing Super Admin"
  echo
  echo "  Name:  $first_name $last_name"
  echo "  Email: $email"
  echo
}

_data_reset_super_admin_password() {
  echo
  local password
  password="$(gum input --placeholder "New password (leave blank to generate)")"

  local ruby_script
  if [[ -z "$password" ]]; then
    ruby_script="
      ActsAsTenant.without_tenant do
        admin = User.with_role(:super_admin).first
        password = People::PasswordGenerator.instance.generate
        admin.password = password
        admin.password_confirmation = password
        admin.changing_password = true
        if admin.valid?
          admin.save!
          puts password
        else
          STDERR.puts admin.errors[:password].join(', ')
          exit 1
        end
      end
    "
  else
    ruby_script="
      ActsAsTenant.without_tenant do
        admin = User.with_role(:super_admin).first
        admin.password = '$password'
        admin.password_confirmation = '$password'
        admin.changing_password = true
        if admin.valid?
          admin.save!
        else
          STDERR.puts admin.errors[:password].join(', ')
          exit 1
        end
      end
    "
  fi

  echo
  msg_success "==> Updating password..."

  local result exit_code
  result="$(bundle exec rails runner "$ruby_script" 2>&1)"
  exit_code=$?
  result="$(echo "$result" | grep -v "QueryTrace" || true)"

  if [[ $exit_code -ne 0 ]]; then
    msg_error "Failed to update password: $result"
    echo
    press_enter
    return 1
  fi

  echo
  msg_success "Password updated successfully!"
  if [[ -z "$password" ]]; then
    echo "  Generated password: $result"
  fi
  echo
  press_enter
}

_data_offer_provisioning() {
  if _data_database_exists; then
    local admin_info
    admin_info="$(_data_get_super_admin)"

    if [[ -n "$admin_info" ]]; then
      while true; do
        _data_show_existing_admin "$admin_info"

        local choice
        choice="$(gum choose --header "Database already provisioned. What would you like to do?" \
          "Keep existing setup" \
          "Reset super admin password" \
          "Provision new database (destructive)")"

        case "$choice" in
          "Keep existing setup")
            msg_success "Keeping existing database."
            return
            ;;
          "Reset super admin password")
            _data_reset_super_admin_password || continue
            return
            ;;
          "Provision new database (destructive)")
            echo
            msg_error "WARNING: This will permanently delete all data in the database!"
            echo
            if ! gum confirm "Are you sure you want to drop and recreate the database?"; then
              continue
            fi
            echo
            msg_success "==> Dropping database..."
            bundle exec rake db:drop 2>&1 | filter_noise
            _data_provision_database
            return
            ;;
        esac
      done
    fi
  fi

  if gum confirm "Provision the database?"; then
    _data_provision_database
  fi
}


_data_set_mailman_admin_password() {
  # The mailman-web image creates the admin with an unusable password.
  # Set it to 'gather-mailman-dev' by writing the hash directly to SQLite.
  local container
  container=$(docker ps --filter "name=mailman-web" --filter "status=running" --format "{{.Names}}" 2>/dev/null | head -1)
  [[ -z "$container" ]] && return 0

  printf "  %-16s " "Mailman admin"
  local timeout=60
  local start=$SECONDS
  while ! docker exec "$container" test -f /opt/mailman-web-data/mailmanweb.db 2>/dev/null; do
    if [[ $((SECONDS - start)) -gt $timeout ]]; then
      gum style --foreground 3 "⚠ timed out waiting for Mailman DB"
      return 0
    fi
    sleep 2
  done

  if docker exec "$container" python3 -c "
import sqlite3, hashlib, base64
salt = 'gatherdevelopment'
dk = hashlib.pbkdf2_hmac('sha256', b'gather-mailman-dev', salt.encode(), 390000)
h = 'pbkdf2_sha256\$390000\$' + salt + '\$' + base64.b64encode(dk).decode()
conn = sqlite3.connect('/opt/mailman-web-data/mailmanweb.db')
conn.execute(\"UPDATE auth_user SET password=? WHERE username='admin'\", (h,))
conn.commit()
" 2>/dev/null; then
    gum style --foreground 2 "✓ password set"
  else
    gum style --foreground 1 "✗ failed"
  fi
}

_data_print_access_info() {
  echo
  gum style --bold "Getting Started"
  echo
  echo "  Start the app:    bin/dev"
  echo "  App URL:          https://gatherdev.org:3000"
  echo "  Mailman (Postorius): run bin/mailman-web, then visit port 8000/postorius/  (admin / gather-mailman-dev)"
  echo
}

run_data() {
  echo "Setting up data services..."
  echo

  _data_load_config
  _data_validate_config || return 1

  gum style --bold "Configuration"
  echo
  echo "  PostgreSQL:    $_DATA_PG_HOST:$_DATA_PG_PORT"
  echo "  Redis:         $_DATA_REDIS_URL"
  echo "  Elasticsearch: $_DATA_ES_HOST:$_DATA_ES_PORT"
  echo

  gum style --bold "Connection Status"
  echo

  if _data_test_all_connections; then
    echo
    _data_offer_provisioning
    _data_set_mailman_admin_password
    return 0
  fi

  echo
  if gum confirm "Some services are unavailable. Start them with Docker Compose?"; then
    echo
    _data_start_docker_services || return 1
    echo

    gum style --bold "Connection Status (after starting Docker)"
    echo
    if _data_test_all_connections; then
      echo
      _data_offer_provisioning
      _data_set_mailman_admin_password
      return 0
    else
      echo
      msg_error "Services still not available after starting Docker."
      return 1
    fi
  else
    return 1
  fi
}
