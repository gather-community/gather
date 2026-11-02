# shellcheck shell=bash
# The port the dev server listens on. Each devcontainer on the same Mac needs its own,
# because VS Code forwards it to the same port number on the Mac. Set it as url.port in
# config/settings.local.yml; the default comes from config/settings/development.yml.
# The app uses the same setting to build its URLs, so the two always agree.
dev_port() {
  local port=""
  [[ -f "$ROOT_DIR/config/settings.local.yml" ]] &&
    port="$(yq -r '.url.port // ""' "$ROOT_DIR/config/settings.local.yml")"
  [[ -n "$port" ]] || port="$(yq -r '.url.port' "$ROOT_DIR/config/settings/development.yml")"
  echo "$port"
}
