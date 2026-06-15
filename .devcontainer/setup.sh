#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# -----------------------------------------------------------------------------
# Docker network setup
# -----------------------------------------------------------------------------
# The devcontainer should use the same network as the application so we can reach services by name.
# This should match the network in the compose file and runArgs in devcontainer.json
WORKSPACE_BASENAME="$(basename "$ROOT_DIR")"
echo "==> Setting up Docker network (${WORKSPACE_BASENAME}-network)..."
docker network create "${WORKSPACE_BASENAME}-network" \
  --label "com.docker.compose.network=gather" \
  --label "com.docker.compose.project=${WORKSPACE_BASENAME}" 2>/dev/null || true

# -----------------------------------------------------------------------------
# SSL Certificate setup
# -----------------------------------------------------------------------------
CERT_FILE="$ROOT_DIR/config/ssl/gatherdev.org.crt"
CERT_NAME="gatherdev.org"

detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
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

command_exists() {
  command -v "$1" &>/dev/null
}

# -----------------------------------------------------------------------------
# Certificate detection
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

cert_installed_chrome() {
  local os="$(detect_os)"

  case "$os" in
    macos)
      cert_installed_system
      ;;
    linux)
      if [[ -d "$HOME/.pki/nssdb" ]] && command_exists certutil; then
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

cert_installed_firefox() {
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
}

install_cert_system() {
  local os="$(detect_os)"

  if cert_installed_system; then
    echo "Certificate already in system trust store, skipping"
    return 0
  fi

  echo "Installing certificate to system trust store..."

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
          echo "Warning: Unsupported Linux distribution for system cert install"
          return 1
          ;;
      esac
      ;;
    *)
      echo "Warning: Unsupported operating system"
      return 1
      ;;
  esac

  echo "System trust store: done"
}

install_cert_chrome() {
  local os="$(detect_os)"

  if cert_installed_chrome; then
    echo "Certificate already in Chrome/Chromium, skipping"
    return 0
  fi

  case "$os" in
    macos)
      echo "Chrome on macOS uses system keychain (already installed)"
      ;;
    linux)
      if ! command_exists certutil; then
        echo "Warning: certutil not found, skipping Chrome cert install"
        return 1
      fi

      if [[ ! -d "$HOME/.pki/nssdb" ]]; then
        echo "Creating Chrome NSS database..."
        mkdir -p "$HOME/.pki/nssdb"
        certutil -d sql:"$HOME/.pki/nssdb" -N --empty-password
      fi

      echo "Installing certificate to Chrome/Chromium..."
      certutil -d sql:"$HOME/.pki/nssdb" -D -n "$CERT_NAME" 2>/dev/null || true
      certutil -d sql:"$HOME/.pki/nssdb" -A -t "C,," -n "$CERT_NAME" -i "$CERT_FILE"
      echo "Chrome/Chromium: done"
      ;;
  esac
}

find_firefox_profiles() {
  local profiles=()
  local profile_dirs=(
    "$HOME/.mozilla/firefox"
    "$HOME/snap/firefox/common/.mozilla/firefox"
    "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    "$HOME/Library/Application Support/Firefox/Profiles"
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

install_cert_firefox() {
  if cert_installed_firefox; then
    echo "Certificate already in Firefox, skipping"
    return 0
  fi

  if ! command_exists certutil; then
    echo "Warning: certutil not found, skipping Firefox cert install"
    return 1
  fi

  local profiles
  profiles="$(find_firefox_profiles)"

  if [[ -z "$profiles" ]]; then
    echo "No Firefox profiles found, skipping"
    return 0
  fi

  echo "Installing certificate to Firefox..."
  while IFS= read -r profile; do
    if [[ -f "$profile/cert9.db" ]]; then
      echo "  Profile: $(basename "$profile")"
      certutil -d sql:"$profile" -D -n "$CERT_NAME" 2>/dev/null || true
      certutil -d sql:"$profile" -A -t "C,," -n "$CERT_NAME" -i "$CERT_FILE"
    fi
  done <<< "$profiles"
  echo "Firefox: done"
}

setup_certificates() {
  echo "==> Setting up SSL certificates for gatherdev.org"

  if [[ ! -f "$CERT_FILE" ]]; then
    echo "Warning: Certificate file not found: $CERT_FILE"
    echo "Skipping certificate setup"
    return 0
  fi

  local os="$(detect_os)"
  echo "Detected OS: $os"
  [[ "$os" == "linux" ]] && echo "Detected distro: $(detect_linux_distro)"

  install_cert_system || true

  if [[ "$os" == "linux" ]]; then
    install_cert_chrome || true
  fi

  install_cert_firefox || true

  echo "SSL certificate setup complete"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
setup_certificates

echo "==> Devcontainer setup complete"
