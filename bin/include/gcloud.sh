# shellcheck shell=bash
# Google OAuth configuration via gcloud CLI

configure_google_oauth() {
  clear_screen
  header "Google OAuth via gcloud"
  echo

  if ! command_exists gcloud; then
    msg_error "gcloud CLI is not installed."
    echo
    echo "Install it with: mise install gcloud"
    press_enter
    return
  fi

  msg_success "Checking gcloud authentication..."
  local auth_account
  auth_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"

  if [[ -z "$auth_account" ]]; then
    msg_warn "Not logged in to gcloud. Starting authentication..."
    echo
    if ! gcloud auth login; then
      msg_error "Authentication failed"
      press_enter
      return
    fi
    auth_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
  else
    msg_success "Logged in as: $auth_account"
  fi
  echo

  # Select or create project
  local project_id
  project_id="$(select_or_create_gcloud_project)"
  [[ -z "$project_id" ]] && return

  # Set active project
  msg_success "==> Setting active project to $project_id..."
  if ! gcloud config set project "$project_id"; then
    msg_error "Failed to set project"
    press_enter
    return
  fi

  # Enable required APIs
  msg_success "==> Enabling required APIs..."
  local apis=("iamcredentials.googleapis.com" "oauth2.googleapis.com")
  for api in "${apis[@]}"; do
    echo "    Enabling $api..."
    gcloud services enable "$api" --quiet 2>/dev/null || true
  done
  echo

  # Create OAuth credentials
  create_oauth_credentials "$project_id"
}

select_or_create_gcloud_project() {
  clear_screen
  header "Google Cloud Project"
  echo

  local choice
  choice="$(gum choose --header "Project:" "Select an existing project" "Create a new project")"

  case "$choice" in
    "Select an existing project")
      select_existing_project
      ;;
    "Create a new project")
      create_new_project
      ;;
  esac
}

select_existing_project() {
  echo
  msg_success "Fetching projects..."
  local projects_json
  projects_json="$(gcloud projects list --format='json' 2>/dev/null)"

  if [[ -z "$projects_json" || "$projects_json" == "[]" ]]; then
    msg_warn "No projects found. Please create one."
    press_enter
    return
  fi

  local project_ids
  mapfile -t project_ids < <(echo "$projects_json" | jq -r '.[].projectId')

  if [[ ${#project_ids[@]} -eq 0 ]]; then
    msg_warn "No projects found. Please create one."
    press_enter
    return
  fi

  echo
  local selected
  selected="$(gum choose --header "Select project:" "${project_ids[@]}")"
  echo "$selected"
}

create_new_project() {
  echo

  while true; do
    local project_name
    project_name="$(gum input --placeholder "Project name (e.g., gather-dev)")"

    if [[ -z "$project_name" ]]; then
      msg_error "Project name cannot be empty"
      continue
    fi

    # Sanitize project ID
    local project_id
    project_id="$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g')"

    # Project IDs must be 6-30 characters
    if [[ ${#project_id} -lt 6 ]]; then
      project_id="${project_id}-project"
    fi
    project_id="${project_id:0:30}"

    msg_success "Creating project '$project_id'..."

    if gcloud projects create "$project_id" --name="$project_name" 2>&1; then
      msg_success "Project created successfully!"
      echo "$project_id"
      return
    else
      msg_error "Failed to create project. The name might be taken."
      if ! gum confirm "Try a different name?"; then
        return
      fi
    fi
  done
}

create_oauth_credentials() {
  local project_id="$1"

  clear_screen
  header "OAuth Credentials"
  echo

  msg_success "Checking OAuth consent screen..."
  echo

  msg_warn "To complete OAuth setup, you need to:"
  echo
  echo "  1. Configure the OAuth consent screen"
  echo "  2. Create OAuth 2.0 credentials"
  echo
  echo "Required configuration:"
  echo "  Application type:           Web application"
  echo "  Authorized JS origins:      https://gatherdev.org:3000"
  echo "  Authorized redirect URIs:   https://gatherdev.org:3000/people/users/auth/google_oauth2/callback"
  echo

  local credentials_url="https://console.cloud.google.com/apis/credentials?project=$project_id"

  if gum confirm "Open Google Cloud Console in browser?"; then
    echo
    msg_success "Opening browser..."
    xdg-open "$credentials_url" 2>/dev/null || open "$credentials_url" 2>/dev/null || echo "Visit: $credentials_url"
    echo
    echo "After creating credentials in the console, enter them below:"
  else
    echo
    echo "Visit: $credentials_url"
    echo
    echo "After creating credentials, enter them below:"
  fi

  echo

  # Read existing values for defaults
  read_oauth_config

  GOOGLE_CLIENT_ID="$(gum input --value "$GOOGLE_CLIENT_ID" --placeholder "Client ID")"
  GOOGLE_CLIENT_SECRET="$(gum input --value "$GOOGLE_CLIENT_SECRET" --placeholder "Client Secret")"
  echo

  if [[ -z "$GOOGLE_CLIENT_ID" || -z "$GOOGLE_CLIENT_SECRET" ]]; then
    msg_warn "Credentials not provided - you can configure them later"
  else
    # Write to config file
    write_oauth_config
    msg_success "OAuth credentials saved to config/settings.local.yml!"
  fi

  press_enter
}
