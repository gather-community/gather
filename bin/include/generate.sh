# shellcheck shell=bash
# Full setup wizard - configures all services

run_full_setup() {
  if ! all_deps_ok; then
    show_missing_deps
    return
  fi

  collect_postgres_config
  collect_redis_config
  collect_elasticsearch_config
  collect_oauth_config
  configure_secret_key

  show_setup_completion
}

show_missing_deps() {
  echo
  msg_error "Cannot run setup: missing dependencies"
  echo
  echo "Please install:"
  [[ "${DEPS[libvips]}" != "true" ]] && echo "  - libvips v8.8+"
  press_enter
}

show_setup_completion() {
  clear_screen
  header "Setup Complete"
  echo

  gum style --bold --foreground 2 "All services configured!"
  echo

  echo "Configuration saved to:"
  echo "  - config/database.yml"
  echo "  - config/settings.local.yml"
  echo "  - docker-compose.yml"
  echo

  # Check if any docker services need to be started
  local has_docker_services=false
  read_pg_config
  read_redis_config
  read_es_config

  [[ "$PG_SOURCE" == "docker" ]] && has_docker_services=true
  [[ "$REDIS_SOURCE" == "docker" ]] && has_docker_services=true
  [[ "$ES_SOURCE" == "docker" ]] && has_docker_services=true

  if $has_docker_services; then
    echo "Next steps:"
    echo "  1. Start Docker services:    docker compose up -d"
    echo "  2. Provision database:       Select 'Provision database' from menu"
    echo "  3. Start the server:         bin/dev"
  else
    echo "Next steps:"
    echo "  1. Provision database:       Select 'Provision database' from menu"
    echo "  2. Start the server:         bin/dev"
  fi

  press_enter
}
