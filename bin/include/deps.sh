# shellcheck shell=bash
# Dependency checking and status display

declare -A DEPS

check_dependencies() {
  # Ruby
  if command_exists ruby; then
    DEPS[ruby]="true"
    DEPS[ruby_version]="$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  else
    DEPS[ruby]="false"
    DEPS[ruby_version]="not found"
  fi

  # libvips
  if command_exists vips; then
    local version
    version="$(vips --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    local major minor
    major="${version%%.*}"
    minor="${version#*.}"
    minor="${minor%%.*}"
    if [[ "$major" -gt 8 ]] || { [[ "$major" -eq 8 ]] && [[ "$minor" -ge 8 ]]; }; then
      DEPS[libvips]="true"
      DEPS[libvips_version]="$version"
    else
      DEPS[libvips]="false"
      DEPS[libvips_version]="$version (too old)"
    fi
  else
    DEPS[libvips]="false"
    DEPS[libvips_version]="not found"
  fi

  # Gems
  if bundle check &>/dev/null; then
    DEPS[gems]="true"
  else
    DEPS[gems]="false"
  fi
}

all_deps_ok() {
  [[ "${DEPS[libvips]}" == "true" ]]
}

admin_config_present() {
  [[ -n "$ADMIN_FNAME" && -n "$ADMIN_LNAME" && -n "$ADMIN_EMAIL" ]]
}

show_status() {
  clear_screen
  header
  echo

  gum style --bold "Dependencies"
  echo
  printf "  %-12s %s  %s\n" "ruby" "$(status_icon "${DEPS[ruby]}")" "${DEPS[ruby_version]}"
  printf "  %-12s %s  %s\n" "libvips" "$(status_icon "${DEPS[libvips]}")" "${DEPS[libvips_version]}"
  printf "  %-12s %s\n" "gems" "$(status_icon "${DEPS[gems]}")"
  echo

  gum style --bold "Services"
  echo

  # PostgreSQL
  if pg_configured; then
    printf "  %-14s %s  %s\n" "PostgreSQL" "$(status_icon true)" "$(pg_status_text)"
  else
    printf "  %-14s %s  %s\n" "PostgreSQL" "$(status_icon false)" "$(gum style --foreground 7 "not configured")"
  fi

  # Redis
  if redis_configured; then
    printf "  %-14s %s  %s\n" "Redis" "$(status_icon true)" "$(redis_status_text)"
  else
    printf "  %-14s %s  %s\n" "Redis" "$(status_icon false)" "$(gum style --foreground 7 "not configured")"
  fi

  # Elasticsearch
  if es_configured; then
    printf "  %-14s %s  %s\n" "Elasticsearch" "$(status_icon true)" "$(es_status_text)"
  else
    printf "  %-14s %s  %s\n" "Elasticsearch" "$(status_icon false)" "$(gum style --foreground 7 "not configured")"
  fi

  # Google OAuth
  if oauth_configured; then
    printf "  %-14s %s  %s\n" "Google OAuth" "$(status_icon true)" "$(oauth_status_text)"
  else
    printf "  %-14s %s  %s\n" "Google OAuth" "$(status_icon false)" "$(gum style --foreground 7 "not configured")"
  fi

  # Secret Key
  if secret_key_configured; then
    printf "  %-14s %s  %s\n" "Secret Key" "$(status_icon true)" "configured"
  else
    printf "  %-14s %s  %s\n" "Secret Key" "$(status_icon false)" "$(gum style --foreground 7 "not configured")"
  fi

  echo
}
