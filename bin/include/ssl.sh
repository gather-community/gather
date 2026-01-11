# shellcheck shell=bash
# Manage SSL certificates for local development

_SSL_CERT_FILE=""
_SSL_CERT_NAME="gatherdev.org"

# -----------------------------------------------------------------------------
# System trust store
# -----------------------------------------------------------------------------
_ssl_cert_installed_system() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      security find-certificate -c "$_SSL_CERT_NAME" /Library/Keychains/System.keychain &>/dev/null
      ;;
    linux)
      local distro="$(detect_linux_distro)"
      case "$distro" in
        arch)
          [[ -f "/etc/ca-certificates/trust-source/anchors/${_SSL_CERT_NAME}.crt" ]]
          ;;
        debian)
          [[ -f "/usr/local/share/ca-certificates/${_SSL_CERT_NAME}.crt" ]]
          ;;
        fedora)
          [[ -f "/etc/pki/ca-trust/source/anchors/${_SSL_CERT_NAME}.crt" ]]
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

_ssl_install_cert_system() {
  local os="$(detect_os)"

  if [[ ! -f "$_SSL_CERT_FILE" ]]; then
    msg_error "Certificate file not found: $_SSL_CERT_FILE"
    return 1
  fi

  if _ssl_cert_installed_system; then
    msg_info "Certificate already in system trust store, skipping"
    return 0
  fi

  msg_info "Installing certificate to system trust store..."

  case "$os" in
    macos)
      sudo security add-trusted-cert -d -r trustRoot \
        -k /Library/Keychains/System.keychain "$_SSL_CERT_FILE"
      ;;
    linux)
      local distro="$(detect_linux_distro)"
      case "$distro" in
        arch)
          sudo cp "$_SSL_CERT_FILE" "/etc/ca-certificates/trust-source/anchors/${_SSL_CERT_NAME}.crt"
          sudo update-ca-trust
          ;;
        debian)
          sudo cp "$_SSL_CERT_FILE" "/usr/local/share/ca-certificates/${_SSL_CERT_NAME}.crt"
          sudo update-ca-certificates
          ;;
        fedora)
          sudo cp "$_SSL_CERT_FILE" "/etc/pki/ca-trust/source/anchors/${_SSL_CERT_NAME}.crt"
          sudo update-ca-trust
          ;;
        *)
          msg_error "Unsupported Linux distribution"
          return 1
          ;;
      esac
      ;;
    *)
      msg_error "Unsupported operating system"
      return 1
      ;;
  esac
}

_ssl_remove_cert_system() {
  local os="$(detect_os)"

  msg_info "Removing certificate from system trust store..."

  case "$os" in
    macos)
      sudo security delete-certificate -c "$_SSL_CERT_NAME" /Library/Keychains/System.keychain
      ;;
    linux)
      local distro="$(detect_linux_distro)"
      case "$distro" in
        arch)
          sudo rm -f "/etc/ca-certificates/trust-source/anchors/${_SSL_CERT_NAME}.crt"
          sudo update-ca-trust
          ;;
        debian)
          sudo rm -f "/usr/local/share/ca-certificates/${_SSL_CERT_NAME}.crt"
          sudo update-ca-certificates --fresh
          ;;
        fedora)
          sudo rm -f "/etc/pki/ca-trust/source/anchors/${_SSL_CERT_NAME}.crt"
          sudo update-ca-trust
          ;;
        *)
          msg_error "Unsupported Linux distribution"
          return 1
          ;;
      esac
      ;;
    *)
      msg_error "Unsupported operating system"
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Chrome/Chromium (uses NSS database on Linux)
# -----------------------------------------------------------------------------
_ssl_chrome_nss_db_exists() {
  [[ -d "$HOME/.pki/nssdb" ]]
}

_ssl_cert_installed_chrome() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      _ssl_cert_installed_system
      ;;
    linux)
      if _ssl_chrome_nss_db_exists && command_exists certutil; then
        certutil -d sql:"$HOME/.pki/nssdb" -L -n "$_SSL_CERT_NAME" &>/dev/null
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

_ssl_install_cert_chrome() {
  local os="$(detect_os)"

  if [[ ! -f "$_SSL_CERT_FILE" ]]; then
    msg_error "Certificate file not found: $_SSL_CERT_FILE"
    return 1
  fi

  if _ssl_cert_installed_chrome; then
    msg_info "Certificate already in Chrome/Chromium, skipping"
    return 0
  fi

  case "$os" in
    macos)
      msg_info "Chrome on macOS uses the system keychain."
      _ssl_install_cert_system
      ;;
    linux)
      if ! command_exists certutil; then
        msg_error "certutil not found. Install nss package:"
        local distro="$(detect_linux_distro)"
        case "$distro" in
          arch)   echo "  sudo pacman -S nss" ;;
          debian) echo "  sudo apt install libnss3-tools" ;;
          fedora) echo "  sudo dnf install nss-tools" ;;
        esac
        return 1
      fi

      if ! _ssl_chrome_nss_db_exists; then
        msg_info "Creating Chrome NSS database..."
        mkdir -p "$HOME/.pki/nssdb"
        certutil -d sql:"$HOME/.pki/nssdb" -N --empty-password
      fi

      msg_info "Installing certificate to Chrome/Chromium..."
      certutil -d sql:"$HOME/.pki/nssdb" -A -t "C,," -n "$_SSL_CERT_NAME" -i "$_SSL_CERT_FILE"
      ;;
    *)
      msg_error "Unsupported operating system"
      return 1
      ;;
  esac
}

_ssl_remove_cert_chrome() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      msg_info "Chrome on macOS uses the system keychain."
      _ssl_remove_cert_system
      ;;
    linux)
      if _ssl_chrome_nss_db_exists && command_exists certutil; then
        msg_info "Removing certificate from Chrome/Chromium..."
        certutil -d sql:"$HOME/.pki/nssdb" -D -n "$_SSL_CERT_NAME"
      fi
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Firefox
# -----------------------------------------------------------------------------
_ssl_find_firefox_profiles() {
  local profiles=()
  local profile_dirs=(
    "$HOME/.mozilla/firefox"
    "$HOME/snap/firefox/common/.mozilla/firefox"
    "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
  )

  for dir in "${profile_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r -d '' profile; do
        [[ -f "$profile/cert9.db" ]] && profiles+=("$profile")
      done < <(find "$dir" -maxdepth 2 -type d -name "*.default*" -print0 2>/dev/null)
    fi
  done

  printf '%s\n' "${profiles[@]}"
}

_ssl_cert_installed_firefox() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      local profile_dir="$HOME/Library/Application Support/Firefox/Profiles"
      if [[ -d "$profile_dir" ]] && command_exists certutil; then
        while IFS= read -r -d '' profile; do
          if [[ -f "$profile/cert9.db" ]]; then
            if certutil -d sql:"$profile" -L -n "$_SSL_CERT_NAME" &>/dev/null; then
              return 0
            fi
          fi
        done < <(find "$profile_dir" -maxdepth 1 -type d -name "*.default*" -print0 2>/dev/null)
      fi
      return 1
      ;;
    linux)
      if ! command_exists certutil; then
        return 1
      fi
      local profiles
      profiles="$(_ssl_find_firefox_profiles)"
      [[ -z "$profiles" ]] && return 1

      while IFS= read -r profile; do
        if certutil -d sql:"$profile" -L -n "$_SSL_CERT_NAME" &>/dev/null; then
          return 0
        fi
      done <<< "$profiles"
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

_ssl_install_cert_firefox() {
  local os="$(detect_os)"

  if [[ ! -f "$_SSL_CERT_FILE" ]]; then
    msg_error "Certificate file not found: $_SSL_CERT_FILE"
    return 1
  fi

  if _ssl_cert_installed_firefox; then
    msg_info "Certificate already in Firefox, skipping"
    return 0
  fi

  if ! command_exists certutil; then
    msg_error "certutil not found. Install nss package:"
    local distro="$(detect_linux_distro)"
    case "$distro" in
      arch)   echo "  sudo pacman -S nss" ;;
      debian) echo "  sudo apt install libnss3-tools" ;;
      fedora) echo "  sudo dnf install nss-tools" ;;
    esac
    return 1
  fi

  local profiles
  case "$os" in
    macos)
      profiles=$(find "$HOME/Library/Application Support/Firefox/Profiles" \
        -maxdepth 1 -type d -name "*.default*" 2>/dev/null)
      ;;
    linux)
      profiles="$(_ssl_find_firefox_profiles)"
      ;;
  esac

  if [[ -z "$profiles" ]]; then
    msg_warn "No Firefox profiles found."
    return 1
  fi

  msg_info "Installing certificate to Firefox..."
  while IFS= read -r profile; do
    if [[ -f "$profile/cert9.db" ]]; then
      msg_info "  Profile: $(basename "$profile")"
      certutil -d sql:"$profile" -A -t "C,," -n "$_SSL_CERT_NAME" -i "$_SSL_CERT_FILE"
    fi
  done <<< "$profiles"
}

_ssl_remove_cert_firefox() {
  if ! command_exists certutil; then
    return 1
  fi

  local os="$(detect_os)"
  local profiles

  case "$os" in
    macos)
      profiles=$(find "$HOME/Library/Application Support/Firefox/Profiles" \
        -maxdepth 1 -type d -name "*.default*" 2>/dev/null)
      ;;
    linux)
      profiles="$(_ssl_find_firefox_profiles)"
      ;;
  esac

  [[ -z "$profiles" ]] && return 0

  msg_info "Removing certificate from Firefox..."
  while IFS= read -r profile; do
    if [[ -f "$profile/cert9.db" ]]; then
      certutil -d sql:"$profile" -D -n "$_SSL_CERT_NAME" 2>/dev/null || true
    fi
  done <<< "$profiles"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
run_ssl() {
  _SSL_CERT_FILE="$ROOT_DIR/config/ssl/gatherdev.org.crt"

  echo "Configuring SSL certificates..."
  echo

  if [[ ! -f "$_SSL_CERT_FILE" ]]; then
    msg_error "Certificate file not found: $_SSL_CERT_FILE"
    echo
    echo "Generate it with:"
    echo "  cd config/ssl && openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \\"
    echo "    -keyout gatherdev.org.key -out gatherdev.org.crt -config req.conf -extensions v3_req"
    return 1
  fi

  local os="$(detect_os)"
  echo "Detected OS: $os"
  [[ "$os" == "linux" ]] && echo "Detected distro: $(detect_linux_distro)"
  echo
  echo "Certificate: $_SSL_CERT_FILE"
  echo

  # Check for Firefox profiles
  local has_firefox=false
  local firefox_profiles=""
  case "$os" in
    macos)
      firefox_profiles="$(find "$HOME/Library/Application Support/Firefox/Profiles" -maxdepth 1 -type d -name "*.default*" 2>/dev/null || true)"
      ;;
    linux)
      firefox_profiles="$(_ssl_find_firefox_profiles)"
      ;;
  esac
  [[ -n "$firefox_profiles" ]] && has_firefox=true

  gum style --bold "Current Status"
  echo
  printf "  %-16s %s\n" "System" "$(_ssl_cert_installed_system && echo "$(gum style --foreground 2 '✓ installed')" || echo "$(gum style --foreground 1 '✗ not installed')")"

  if [[ "$os" == "linux" ]]; then
    printf "  %-16s %s\n" "Chrome/Chromium" "$(_ssl_cert_installed_chrome && echo "$(gum style --foreground 2 '✓ installed')" || echo "$(gum style --foreground 1 '✗ not installed')")"
  fi

  if [[ "$has_firefox" == "true" ]]; then
    printf "  %-16s %s\n" "Firefox" "$(_ssl_cert_installed_firefox && echo "$(gum style --foreground 2 '✓ installed')" || echo "$(gum style --foreground 1 '✗ not installed')")"
  fi
  echo

  # Build menu options
  local menu_options=("Install to all" "Install to system" "Install to Chrome/Chromium")
  [[ "$has_firefox" == "true" ]] && menu_options+=("Install to Firefox")
  menu_options+=("Remove from all" "Do nothing")

  local choice
  choice="$(gum choose --header "Select action:" "${menu_options[@]}")"

  case "$choice" in
    "Install to all")
      _ssl_install_cert_system && msg_success "System: done"
      [[ "$os" == "linux" ]] && _ssl_install_cert_chrome && msg_success "Chrome: done"
      [[ "$has_firefox" == "true" ]] && _ssl_install_cert_firefox && msg_success "Firefox: done"
      echo
      msg_success "Certificate installation complete!"
      msg_warn "You may need to restart your browser(s)."
      ;;
    "Install to system")
      _ssl_install_cert_system && msg_success "Done!"
      ;;
    "Install to Chrome/Chromium")
      _ssl_install_cert_chrome && msg_success "Done! Restart Chrome to apply."
      ;;
    "Install to Firefox")
      _ssl_install_cert_firefox && msg_success "Done! Restart Firefox to apply."
      ;;
    "Remove from all")
      _ssl_remove_cert_system
      [[ "$os" == "linux" ]] && _ssl_remove_cert_chrome
      _ssl_remove_cert_firefox
      msg_success "Certificate removed from all stores."
      ;;
    "Do nothing")
      return 0
      ;;
  esac
}
