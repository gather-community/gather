# shellcheck shell=bash
# Generate default configuration files

_conf_config_exists() {
  [[ -f "$ROOT_DIR/config/database.yml" ]] || [[ -f "$ROOT_DIR/config/settings.local.yml" ]]
}

_conf_get_existing_secret_key() {
  local settings_yml="$ROOT_DIR/config/settings.local.yml"
  if [[ -f "$settings_yml" ]]; then
    yq -r '.secret_key_base // ""' "$settings_yml" 2>/dev/null || echo ""
  fi
}

_conf_backup_configs() {
  local database_yml="$ROOT_DIR/config/database.yml"
  local settings_yml="$ROOT_DIR/config/settings.local.yml"
  [[ -f "$database_yml" ]] && cp "$database_yml" "$database_yml.bak"
  [[ -f "$settings_yml" ]] && cp "$settings_yml" "$settings_yml.bak"
}

run_conf() {
  local database_yml="$ROOT_DIR/config/database.yml"
  local settings_yml="$ROOT_DIR/config/settings.local.yml"
  local templates_dir="$ROOT_DIR/config/templates"

  echo "Generating configuration..."
  echo

  local existing_secret_key=""
  local keep_secret_key=false

  if _conf_config_exists; then
    msg_warn "Configuration files already exist."
    if ! gum confirm "Generate new configuration?"; then
      return 0
    fi

    existing_secret_key="$(_conf_get_existing_secret_key)"
    if [[ -n "$existing_secret_key" ]]; then
      if gum confirm "Keep existing secret_key_base? (Changing it will invalidate all sessions)"; then
        keep_secret_key=true
      fi
    fi

    _conf_backup_configs
    msg_success "Backup created"
    echo
  fi

  # Copy templates
  cp "$templates_dir/database.yml" "$database_yml"
  cp "$templates_dir/settings.local.yml" "$settings_yml"

  # Set secret key
  local secret_key
  if [[ "$keep_secret_key" == "true" ]]; then
    secret_key="$existing_secret_key"
  else
    secret_key="$(openssl rand -hex 64)"
  fi
  yq -i ".secret_key_base = \"$secret_key\"" "$settings_yml"

  msg_success "Configuration files generated!"
  echo
  echo "  config/database.yml"
  echo "  config/settings.local.yml"
}
