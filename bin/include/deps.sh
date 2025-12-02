# shellcheck shell=bash
# Check development dependencies

run_deps() {
  echo "Checking dependencies..."
  echo

  local all_ok=true

  # Mise
  local mise_ok
  if mise doctor &>/dev/null; then
    mise_ok="true"
  else
    mise_ok="false"
    all_ok=false
  fi
  printf "  %-12s %s\n" "mise doctor" "$(status_icon "$mise_ok")"

  # Ruby
  local ruby_ok ruby_version
  if command_exists ruby; then
    ruby_ok="true"
    ruby_version="$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  else
    ruby_ok="false"
    ruby_version="not found"
    all_ok=false
  fi
  printf "  %-12s %s  %s\n" "ruby" "$(status_icon "$ruby_ok")" "$ruby_version"

  # libvips
  local libvips_ok libvips_version version major minor
  if command_exists vips; then
    version="$(vips --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    major="${version%%.*}"
    minor="${version#*.}"
    minor="${minor%%.*}"
    if [[ "$major" -gt 8 ]] || { [[ "$major" -eq 8 ]] && [[ "$minor" -ge 8 ]]; }; then
      libvips_ok="true"
      libvips_version="$version"
    else
      libvips_ok="false"
      libvips_version="$version (too old)"
      all_ok=false
    fi
  else
    libvips_ok="false"
    libvips_version="not found"
    all_ok=false
  fi
  printf "  %-12s %s  %s\n" "libvips" "$(status_icon "$libvips_ok")" "$libvips_version"

  # Gems
  local gems_ok
  if bundle check &>/dev/null; then
    gems_ok="true"
  else
    gems_ok="false"
    all_ok=false
  fi
  printf "  %-12s %s\n" "gems" "$(status_icon "$gems_ok")"

  echo

  if [[ "$all_ok" == "true" ]]; then
    msg_success "All dependencies satisfied."
    return 0
  else
    msg_error "Some dependencies are missing."
    return 1
  fi
}
