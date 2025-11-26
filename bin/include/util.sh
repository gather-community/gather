# shellcheck shell=bash
# Utility functions for UI rendering and common operations

cleanup() {
  echo
  gum style --foreground 3 "Setup cancelled."
  exit 0
}

command_exists() {
  command -v "$1" &>/dev/null
}

clear_screen() {
  printf '\e[H\e[2J'
}

header() {
  local title="Gather Development Setup"
  [[ -n "${1:-}" ]] && title="$title — $1"
  gum style --border double --padding "0 2" --margin "0 0 1 0" "$title"
}

status_icon() {
  if [[ "$1" == "true" ]]; then
    gum style --foreground 2 "✓"
  else
    gum style --foreground 1 "✗"
  fi
}

press_enter() {
  echo
  gum input --placeholder "Press Enter to continue..."
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
