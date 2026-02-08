# shellcheck shell=bash
# Shared utilities for setup scripts

command_exists() {
  command -v "$1" &>/dev/null
}

status_icon() {
  if [[ "$1" == "true" ]]; then
    gum style --foreground 2 "✓"
  else
    gum style --foreground 1 "✗"
  fi
}

msg_success() {
  gum style --foreground 2 "$1"
}

msg_error() {
  gum style --foreground 1 "$1"
}

msg_warn() {
  gum style --foreground 3 "$1"
}

msg_info() {
  gum style --foreground 4 "$1"
}

press_enter() {
  gum input --placeholder "Press Enter to continue..." > /dev/null
}

# Filter out QueryTrace noise from Rails output
filter_noise() {
  grep -v "QueryTrace" || true
}

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
