# Gather

The App for Community - https://info.gather.coop

## Platform

Ruby on Rails applications are best developed and run on Linux, Unix, or Mac OS. Development is also possible, though not recommended, on Windows. See the [Rails website](http://rubyonrails.org/) for more information.

Gather is a Ruby on Rails application with some client-side JavaScript for dynamic view elements. HTML is rendered server-side. [SCSS](http://sass-lang.com/) is used for styling.

Development is supported on Linux and macOS. Windows is not supported.

## Quick Start

The easiest way to get started is with VS Code and Dev Containers:

1. Install [Docker](https://www.docker.com/) and [VS Code](https://code.visualstudio.com/)
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Clone and open the project:
   ```bash
   git clone https://github.com/gather-community/gather.git
   code gather
   ```
4. When prompted, click "Reopen in Container" (or run `Dev Containers: Reopen in Container` from the command palette)
5. Once the container is built, run:
   ```bash
   mise setup
   ```

## System Dependencies

We recommend using [mise](https://mise.jdx.dev/) for managing tool versions and running configuration tasks. The project includes a `mise.toml` that installs Ruby, Node.js, and other required tools automatically.

### Required Tools

| Tool                       | Purpose             |
| -------------------------- | ------------------- |
| Ruby (see `.ruby-version`) | Application runtime |
| Node.js (see `.nvmrc`)     | JavaScript tooling  |
| libvips 8.8+               | Image processing    |

### Optional Tools

| Tool        | Purpose                                                           |
| ----------- | ----------------------------------------------------------------- |
| Docker      | Only required if using the repo's `compose.yml` for data services |
| Mailcatcher | Email testing (`gem install mailcatcher`)                         |
| Mailman 3   | Mailing list integration (see below)                              |

## Setup Stages

Run individual setup stages with:

```bash
mise deps    # Check dependencies
mise conf    # Generate configuration
mise data    # Setup data services and database
mise ssl     # Configure SSL certificates
```

The `mise data` stage will create an admin user for development. If you need to reset the admin password later, run `mise data` again and select "Reset super admin password".

## Running the Application

1. **Start data services** (PostgreSQL, Redis, Elasticsearch):

   ```bash
   docker compose up -d
   ```

   If you're using your own data services, ensure they're running and configured in `config/database.yml` and `config/settings.local.yml`. The `mise data` task will attempt to start Docker Compose services if it can't connect to the configured hosts.

2. **Run tests** to verify everything is working:

   ```bash
   bundle exec rspec
   ```

3. **Start the application**:
   ```bash
   bin/dev           # Start Rails server with foreman
   bin/delayed_job run  # Start background job processor (separate terminal)
   ```
   Job logs go to `log/development.log`. The `log/delayed_job.log` file contains only initialization and job state information.

## Running Multiple Dev Envs

Multiple clones of the repo (e.g. `gather1`, `gather2`) can run simultaneously on the same machine. Each gets its own isolated Docker network and database, named after the workspace folder.

Each new instance adds about 3 GB of memory. Ensure your Docker is configured to allow this.

### How isolation works

The devcontainer joins a network named `<folder>-network` (e.g. `gather2-network`). Docker services started by `docker compose up -d` join the same network, so the devcontainer can reach them by hostname (`postgres`, `redis`, `elasticsearch`, `mailman-core`) without any host port bindings. Services in different instances are on separate networks and cannot see each other.

```
┌──────────────────────────────── Mac Host ──────────────────────────────────────────────┐
│                                                                                         │
│   Browser      :3000 ◄── VS Code (process-detect)    :1080 :8000 ◄── Docker host bind  │
│                      (one dev env at a time)           (opt-in, one dev env at a time)  │
│                          │                                │      │                       │
└──────────────────────────┼────────────────────────────────┼──────┼─────────────────── ─ ┘
                           │                                │      │
     ┌─────────────────────┼──── gather1-network ───────────┼──────┼─────────────────┐
     │                     │                                │      │                 │
     │  ┌──────────────────▼────────────────────┐  ┌───────▼──┐ ┌─▼───────────┐    │
     │  │        gather1 devcontainer            │  │mailcatch │ │ mailman-web │    │
     │  │   Rails :3000    Selenium :4444        │  │:1025/1080│ │    :8000    │    │
     │  └──────────────────────────────────────┘  └──────────┘ └─────────────┘    │
     │  postgres:5432  redis:6379  elasticsearch:9200  mailman-core:8001           │
     └───────────────────────────────────────────────────────────────────────────────┘

     ┌──────────────────────── gather2-network ─────────────────────────────────────────┐
     │                                                                                   │
     │  ┌──────────────────────────────────────┐  ┌──────────┐ ┌─────────────┐         │
     │  │        gather2 devcontainer           │  │mailcatch │ │ mailman-web │         │
     │  │   Rails :3000    Selenium :4444       │  │:1025/1080│ │    :8000    │         │
     │  └──────────────────────────────────────┘  └──────────┘ └─────────────┘         │
     │  postgres:5432  redis:6379  elasticsearch:9200  mailman-core:8001                │
     └─────────────────────────────────────────────────────────────────────────────────┘
```

All dev envs are symmetrical — no host port bindings for any service. The devcontainer is on the same Docker network, so services are reachable by hostname (`psql -h postgres`, `redis-cli -h redis`, etc.) from the devcontainer terminal without any host bindings.

**Rails on :3000** runs inside the devcontainer. VS Code detects the process binding and forwards it to the host automatically (`remote.autoForwardPortsSource: "process"` in `devcontainer.json`).

### Setting up a secondary instance

Replacing N with a unique suffix of your choice, run:

```
git clone https://github.com/gather-community/gather.git gatherN
cd gatherN
code .
```

Inside the container, run:

```
mise setup
```

### Tearing down a dev env

To fully remove a dev environment and free up all its Docker resources, run from your Mac terminal in the project directory:

```bash
bin/teardown
```

This removes:
- All Docker Compose services and their data volumes (postgres, redis, elasticsearch, mailcatcher, mailman-*)
- The devcontainer
- The gem bundle volume (`<name>-bundle`)
- The Docker network (`<name>-network`)

Your source code is not touched. To bring the environment back up, reopen the folder in VS Code and run `mise setup`.

### Checking for port conflicts

`bin/dev` checks automatically whether port 3000 is already claimed before starting Rails. If another dev env owns it, you'll see which one and be told to stop it first.

### Exposing sibling container UIs

Mailcatcher and the Mailman web UI are sibling containers — VS Code can't port-forward them. When you need to view one in a browser, run:

```bash
bin/mailcatcher       # http://localhost:1080  (SMTP: localhost:1025)
bin/mailman-web       # http://localhost:8000
```

This recreates that container with a host port binding. If another dev env already has that port bound, the script will report which container owns it and how to stop it. Only one dev env can expose each service at a time.

To remove the binding when done:

```bash
bin/mailcatcher stop
bin/mailman-web stop
```

## Secrets & Configuration

Gather does not use Rails encrypted credentials. Secrets are managed through two files:

`config/settings.local.yml` (gitignored, generated by `mise conf` from the template at `config/templates/settings.local.yml`). Add any local overrides and secrets here.

Never commit secrets to the repository. When adding a new secret, document it with a blank value in `config/templates/settings.local.yml` (this file is checked in) so other developers know what to configure.

## Rails Console

When using the Rails console, set a tenant first:

```ruby
CH.tenant(1)  # Use Community ID 1
```

## Common Shortcuts

Short scripts in `bin/` for frequent tasks:

```bash
bin/c    # rails console
bin/db   # rails dbconsole (psql)
bin/dm   # db:migrate
bin/dr   # db:rollback (accepts STEP=n)
bin/dmr  # db:migrate:redo (accepts STEP=n)
```

## Caching

Caching is off by default in development. Enable temporarily with:

```bash
CACHE=1 rails server
```

## Linters

We use eslint, rubocop, and scss_lint. The CI system enforces these—PRs won't be approved until issues are resolved.

## Troubleshooting

### Elasticsearch 403 Errors

Reset the index:

```ruby
rails console -e development
Work::Shift.__elasticsearch__.create_index!(force: true)
```

To re-populate after resetting:

```ruby
ActsAsTenant.current_tenant = Cluster.find(...)
Work::Shift.find_each { |s| s.__elasticsearch__.index_document }
```

## Mailman 3 Setup

Only required if working on mailing list integration.

Mailman runs as two Docker containers (`mailman-core` and `mailman-web`) included in `docker-compose.yml`. Running `mise data` (or `docker compose up -d`) starts them alongside the other services. A Postorius admin account is created automatically with username `admin` and password `gather-mailman-dev`.

### Inspecting list state (Postorius web UI)

Run `bin/mailman-web` first to bind port 8000, then visit [http://localhost:8000/postorius/](http://localhost:8000/postorius/) and log in with the superuser you created above. From here you can browse domains, lists, and memberships.

### Inspecting list state (REST API)

All REST API calls use HTTP Basic auth with `restadmin` / `restpass`. Run these from inside the devcontainer using `mailman-core` as the hostname (mailman-core has no host port binding, so these commands won't work from the Mac terminal).

```bash
# List all mailing lists
curl -u restadmin:restpass http://mailman-core:8001/3.1/lists

# Show a specific list (replace list@domain with the actual address)
curl -u restadmin:restpass http://mailman-core:8001/3.1/lists/list@domain

# Show all members of a list
curl -u restadmin:restpass "http://mailman-core:8001/3.1/lists/list@domain/roster/member?count=100&page=1"

# Show nonmembers (allowed senders) of a list
curl -u restadmin:restpass "http://mailman-core:8001/3.1/lists/list@domain/roster/nonmember?count=100&page=1"

# Show a specific membership by ID
curl -u restadmin:restpass http://mailman-core:8001/3.1/members/MEMBER_ID
```

### Making modifications (REST API)

```bash
# Add a member to a list
curl -u restadmin:restpass -X POST http://mailman-core:8001/3.1/members \
  -d "list_id=list.domain&subscriber=user@example.com&role=member&pre_verified=true&pre_confirmed=true&pre_approved=true"

# Update a membership (e.g. set moderation_action to accept)
curl -u restadmin:restpass -X PATCH http://mailman-core:8001/3.1/members/MEMBER_ID \
  -d "moderation_action=accept"

# Delete a membership
curl -u restadmin:restpass -X DELETE http://mailman-core:8001/3.1/members/MEMBER_ID

# Update list settings
curl -u restadmin:restpass -X PATCH http://mailman-core:8001/3.1/lists/list@domain/config \
  -d "advertised=false"
```

### Viewing logs

```bash
docker logs mailman-core        # Mailman core logs (REST API, delivery, errors)
docker logs mailman-web         # Postorius web UI logs
docker logs -f mailman-core     # Follow logs in real time
```

### Dropping into a shell

```bash
docker exec -it mailman-core bash
```

## VS Code

When using Dev Containers, extensions and settings are installed and configured automatically.

If working locally without a Dev Container, install these recommended extensions:

**Ruby/Rails:**

- `Shopify.ruby-lsp` - Ruby language server
- `Shopify.ruby-extensions-pack` - Ruby extensions pack
- `KoichiSasada.vscode-rdbg` - Ruby debugger
- `rubocop.vscode-rubocop` - RuboCop linting
- `aliariff.vscode-erb-beautify` - ERB formatting

**JavaScript/TypeScript:**

- `dbaeumer.vscode-eslint` - ESLint
- `esbenp.prettier-vscode` - Prettier formatting
- `marcoroth.stimulus-lsp` - Stimulus (Hotwire) support
- `bradlc.vscode-tailwindcss` - Tailwind CSS

**Utilities:**

- `hverlin.mise-vscode` - mise integration
- `ckolkman.vscode-postgres` - PostgreSQL client
- `ms-azuretools.vscode-docker` - Docker support
- `foxundermoon.shell-format` - Shell script formatting
- `timonwong.shellcheck` - Shell script linting
- `EditorConfig.EditorConfig` - EditorConfig support

**Recommended settings** (`.vscode/settings.json`):

```json
{
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[ruby]": {
    "editor.defaultFormatter": "Shopify.ruby-lsp"
  },
  "[erb]": {
    "editor.defaultFormatter": "aliariff.vscode-erb-beautify"
  },
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  "files.associations": {
    "*.html.erb": "erb"
  }
}
```

## Acknowledgements

This project is happily tested with BrowserStack!

[![Tested with BrowserStack](https://www.browserstack.com/images/layout/browserstack-logo-600x315.png)](https://www.browserstack.com)
