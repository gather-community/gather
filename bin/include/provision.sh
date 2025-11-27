# shellcheck shell=bash
# Database provisioning

provision_database() {
  admin_config_present || collect_admin_config

  clear_screen
  header "Provisioning Database"
  echo

  # Ensure docker network exists
  docker network create gather-network 2>/dev/null || true

  # Start docker compose services
  msg_success "==> Starting Docker services..."
  if ! docker compose up -d; then
    msg_error "Failed to start Docker services"
    press_enter
    return
  fi

  # Wait for postgres to be healthy
  msg_success "==> Waiting for PostgreSQL to be ready..."
  if ! wait_for_postgres; then
    msg_error "PostgreSQL failed to become healthy"
    press_enter
    return
  fi

  # Create and setup database
  msg_success "==> Creating database..."
  if ! bundle exec rake db:create; then
    msg_error "Failed to create database"
    press_enter
    return
  fi

  msg_success "==> Loading schema..."
  if ! bundle exec rake db:schema:load; then
    msg_error "Failed to load schema"
    press_enter
    return
  fi

  # Create admin user and seed data
  msg_success "==> Creating cluster with admin user..."
  if ! bundle exec rake db:new_cluster \
      ADMIN_FNAME="$ADMIN_FNAME" \
      ADMIN_LNAME="$ADMIN_LNAME" \
      ADMIN_EMAIL="$ADMIN_EMAIL" \
      SUPER_ADMIN=y; then
    msg_error "Failed to create cluster"
    press_enter
    return
  fi

  echo
  gum style --bold --foreground 2 "Database provisioned successfully!"
  echo
  echo "You can now start the application:"
  echo "  1. Start the server:         bin/dev"
  echo "  2. Start background jobs:    bin/delayed_job run"
  echo
  echo "Access the app at:      https://gatherdev.org:3000"
  echo "Mailcatcher UI at:      http://localhost:1080"

  press_enter
}

wait_for_postgres() {
  local timeout=60
  local start_time=$SECONDS

  while true; do
    # Check if postgres container is healthy
    local result
    result="$(docker compose ps postgres --format json 2>/dev/null || true)"
    if [[ "$result" == *'"Health":"healthy"'* ]] || [[ "$result" == *'health: healthy'* ]]; then
      return 0
    fi

    # Also try direct health check
    if docker compose exec -T postgres pg_isready -U "${PG_USER:-gather}" &>/dev/null; then
      return 0
    fi

    if [[ $((SECONDS - start_time)) -gt $timeout ]]; then
      return 1
    fi

    sleep 2
    printf "."
  done
}
