# shellcheck shell=bash
# SSL certificate management for local development

CERT_FILE="$ROOT_DIR/config/ssl/gatherdev.org.crt"
CERT_NAME="gatherdev.org"

# -----------------------------------------------------------------------------
# Detection helpers
# -----------------------------------------------------------------------------
detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

detect_linux_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "$ID" in
      arch|manjaro|endeavouros) echo "arch" ;;
      ubuntu|debian|pop|mint|elementary) echo "debian" ;;
      fedora|rhel|centos|rocky|alma) echo "fedora" ;;
      opensuse*|suse*) echo "suse" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

# -----------------------------------------------------------------------------
# System trust store
# -----------------------------------------------------------------------------
cert_installed_system() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      security find-certificate -c "$CERT_NAME" /Library/Keychains/System.keychain &>/dev/null
      ;;
    linux)
      local distro="$(detect_linux_distro)"
      case "$distro" in
        arch)
          [[ -f "/etc/ca-certificates/trust-source/anchors/${CERT_NAME}.crt" ]]
          ;;
        debian)
          [[ -f "/usr/local/share/ca-certificates/${CERT_NAME}.crt" ]]
          ;;
        fedora)
          [[ -f "/etc/pki/ca-trust/source/anchors/${CERT_NAME}.crt" ]]
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

install_cert_system() {
  local os="$(detect_os)"

  if [[ ! -f "$CERT_FILE" ]]; then
    msg_error "Certificate file not found: $CERT_FILE"
    return 1
  fi

  msg_info "Installing certificate to system trust store..."

  case "$os" in
    macos)
      sudo security add-trusted-cert -d -r trustRoot \
        -k /Library/Keychains/System.keychain "$CERT_FILE"
      ;;
    linux)
      local distro="$(detect_linux_distro)"
      case "$distro" in
        arch)
          sudo cp "$CERT_FILE" "/etc/ca-certificates/trust-source/anchors/${CERT_NAME}.crt"
          sudo update-ca-trust
          ;;
        debian)
          sudo cp "$CERT_FILE" "/usr/local/share/ca-certificates/${CERT_NAME}.crt"
          sudo update-ca-certificates
          ;;
        fedora)
          sudo cp "$CERT_FILE" "/etc/pki/ca-trust/source/anchors/${CERT_NAME}.crt"
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

remove_cert_system() {
  local os="$(detect_os)"

  msg_info "Removing certificate from system trust store..."

  case "$os" in
    macos)
      sudo security delete-certificate -c "$CERT_NAME" /Library/Keychains/System.keychain
      ;;
    linux)
      local distro="$(detect_linux_distro)"
      case "$distro" in
        arch)
          sudo rm -f "/etc/ca-certificates/trust-source/anchors/${CERT_NAME}.crt"
          sudo update-ca-trust
          ;;
        debian)
          sudo rm -f "/usr/local/share/ca-certificates/${CERT_NAME}.crt"
          sudo update-ca-certificates --fresh
          ;;
        fedora)
          sudo rm -f "/etc/pki/ca-trust/source/anchors/${CERT_NAME}.crt"
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
chrome_nss_db_exists() {
  [[ -d "$HOME/.pki/nssdb" ]]
}

cert_installed_chrome() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      # Chrome on macOS uses the system keychain
      cert_installed_system
      ;;
    linux)
      if chrome_nss_db_exists && command_exists certutil; then
        certutil -d sql:"$HOME/.pki/nssdb" -L -n "$CERT_NAME" &>/dev/null
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

install_cert_chrome() {
  local os="$(detect_os)"

  if [[ ! -f "$CERT_FILE" ]]; then
    msg_error "Certificate file not found: $CERT_FILE"
    return 1
  fi

  case "$os" in
    macos)
      # Chrome on macOS uses the system keychain
      msg_info "Chrome on macOS uses the system keychain."
      install_cert_system
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

      # Create NSS database if it doesn't exist
      if ! chrome_nss_db_exists; then
        msg_info "Creating Chrome NSS database..."
        mkdir -p "$HOME/.pki/nssdb"
        certutil -d sql:"$HOME/.pki/nssdb" -N --empty-password
      fi

      msg_info "Installing certificate to Chrome/Chromium..."
      certutil -d sql:"$HOME/.pki/nssdb" -A -t "C,," -n "$CERT_NAME" -i "$CERT_FILE"
      ;;
    *)
      msg_error "Unsupported operating system"
      return 1
      ;;
  esac
}

remove_cert_chrome() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      msg_info "Chrome on macOS uses the system keychain."
      remove_cert_system
      ;;
    linux)
      if chrome_nss_db_exists && command_exists certutil; then
        msg_info "Removing certificate from Chrome/Chromium..."
        certutil -d sql:"$HOME/.pki/nssdb" -D -n "$CERT_NAME"
      fi
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Firefox (has its own certificate store)
# -----------------------------------------------------------------------------
find_firefox_profiles() {
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

cert_installed_firefox() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      # Check Firefox profiles on macOS
      local profile_dir="$HOME/Library/Application Support/Firefox/Profiles"
      if [[ -d "$profile_dir" ]] && command_exists certutil; then
        while IFS= read -r -d '' profile; do
          if [[ -f "$profile/cert9.db" ]]; then
            if certutil -d sql:"$profile" -L -n "$CERT_NAME" &>/dev/null; then
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
      profiles="$(find_firefox_profiles)"
      [[ -z "$profiles" ]] && return 1

      while IFS= read -r profile; do
        if certutil -d sql:"$profile" -L -n "$CERT_NAME" &>/dev/null; then
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

install_cert_firefox() {
  local os="$(detect_os)"

  if [[ ! -f "$CERT_FILE" ]]; then
    msg_error "Certificate file not found: $CERT_FILE"
    return 1
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
      profiles="$(find_firefox_profiles)"
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
      certutil -d sql:"$profile" -A -t "C,," -n "$CERT_NAME" -i "$CERT_FILE"
    fi
  done <<< "$profiles"
}

remove_cert_firefox() {
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
      profiles="$(find_firefox_profiles)"
      ;;
  esac

  [[ -z "$profiles" ]] && return 0

  msg_info "Removing certificate from Firefox..."
  while IFS= read -r profile; do
    if [[ -f "$profile/cert9.db" ]]; then
      certutil -d sql:"$profile" -D -n "$CERT_NAME" 2>/dev/null || true
    fi
  done <<< "$profiles"
}

# -----------------------------------------------------------------------------
# Status and UI
# -----------------------------------------------------------------------------
cert_file_exists() {
  [[ -f "$CERT_FILE" ]]
}

cert_status_text() {
  local os="$(detect_os)"
  local status=""

  if ! cert_file_exists; then
    echo "certificate file missing"
    return
  fi

  # System
  if cert_installed_system; then
    status+="system"
  fi

  # Chrome (only check separately on Linux)
  if [[ "$os" == "linux" ]] && cert_installed_chrome; then
    [[ -n "$status" ]] && status+=", "
    status+="chrome"
  fi

  # Firefox
  if cert_installed_firefox; then
    [[ -n "$status" ]] && status+=", "
    status+="firefox"
  fi

  if [[ -n "$status" ]]; then
    echo "$status"
  else
    echo "not installed"
  fi
}

cert_any_installed() {
  cert_installed_system || cert_installed_chrome || cert_installed_firefox
}

# -----------------------------------------------------------------------------
# Main cert management function
# -----------------------------------------------------------------------------
manage_certificates() {
  clear_screen
  header "SSL Certificates"
  echo

  if ! cert_file_exists; then
    msg_error "Certificate file not found: $CERT_FILE"
    echo
    echo "Generate it with:"
    echo "  cd config/ssl && openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \\"
    echo "    -keyout gatherdev.org.key -out gatherdev.org.crt -config req.conf -extensions v3_req"
    press_enter
    return
  fi

  local os="$(detect_os)"
  echo "Detected OS: $os"
  [[ "$os" == "linux" ]] && echo "Detected distro: $(detect_linux_distro)"
  echo
  echo "Certificate: $CERT_FILE"
  echo

  gum style --bold "Current Status"
  echo
  printf "  %-16s %s\n" "System" "$(cert_installed_system && echo "$(gum style --foreground 2 '✓ installed')" || echo "$(gum style --foreground 1 '✗ not installed')")"

  if [[ "$os" == "linux" ]]; then
    printf "  %-16s %s\n" "Chrome/Chromium" "$(cert_installed_chrome && echo "$(gum style --foreground 2 '✓ installed')" || echo "$(gum style --foreground 1 '✗ not installed')")"
  fi

  printf "  %-16s %s\n" "Firefox" "$(cert_installed_firefox && echo "$(gum style --foreground 2 '✓ installed')" || echo "$(gum style --foreground 1 '✗ not installed')")"
  echo

  local choice
  choice="$(gum choose --header "Select action:" \
    "Install to all" \
    "Install to system" \
    "Install to Chrome/Chromium" \
    "Install to Firefox" \
    "Remove from all" \
    "Back to main menu")"

  case "$choice" in
    "Install to all")
      install_cert_system && msg_success "System: done"
      [[ "$os" == "linux" ]] && install_cert_chrome && msg_success "Chrome: done"
      install_cert_firefox && msg_success "Firefox: done"
      echo
      msg_success "Certificate installation complete!"
      msg_warn "You may need to restart your browser(s)."
      press_enter
      ;;
    "Install to system")
      install_cert_system && msg_success "Done!"
      press_enter
      ;;
    "Install to Chrome/Chromium")
      install_cert_chrome && msg_success "Done! Restart Chrome to apply."
      press_enter
      ;;
    "Install to Firefox")
      install_cert_firefox && msg_success "Done! Restart Firefox to apply."
      press_enter
      ;;
    "Remove from all")
      remove_cert_system
      [[ "$os" == "linux" ]] && remove_cert_chrome
      remove_cert_firefox
      msg_success "Certificate removed from all stores."
      press_enter
      ;;
    "Back to main menu")
      return
      ;;
  esac
}
