# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Gather is a Ruby on Rails community management platform for cooperative housing. It handles meals, work scheduling, billing, calendars, wiki, groups, and member directories. Multi-tenant via `acts_as_tenant` with Cluster as the tenant.

## Common Commands

### Running the App
```bash
bin/dev                  # Start Rails + JS build + type checking (via foreman/Procfile.dev)
bin/delayed_job run      # Background jobs (separate terminal)
docker compose up -d     # Start PostgreSQL, Redis, Elasticsearch, Mailcatcher
```

### Tests
```bash
bundle exec rspec                              # All tests
bundle exec rspec spec/models/user_spec.rb     # Single file
bundle exec rspec spec/models/user_spec.rb:42  # Single test by line
```

### Linting
```bash
bundle exec rubocop                  # Ruby (uses standard gem + rubocop-rails)
bundle exec rubocop -a               # Ruby auto-fix
yarn eslint app/javascript           # JavaScript
yarn check-types                     # TypeScript type checking
```

### Database
```bash
bin/rails db:migrate
bin/rails db:setup       # Create + seed
```

### Rails Console
```ruby
CH.tenant(1)  # Must set tenant before querying
```

## Architecture

### Multi-Tenancy Hierarchy
`Cluster` → `Community` → `Household` → `User`

- **Cluster** is the ActsAsTenant tenant. All queries are automatically scoped to the current cluster.
- **Community** scoping is handled by policies and controllers, not ActsAsTenant.
- Users have global roles: `super_admin`, `cluster_admin`, `admin`, plus community-specific roles like `biller`, `meals_coordinator`, `work_coordinator`.

### Feature Modules
Code is organized by feature domain. Each module has its own models, controllers, decorators, policies, jobs, and mailers under matching namespaces:

| Module | Table Prefix | Key Models |
|--------|-------------|------------|
| `Meals` | `meal_` | Meal, Signup, Assignment, Formula, Role, Type |
| `Work` | `work_` | Job, Shift, Period, Assignment |
| `Calendars` | `calendar_` | Calendar, Event, Protocol, Group |
| `Billing` | `billing_` | Account, Statement, Transaction, Template |
| `People` | (none) | User, Household, MemberType, Memorial |
| `Groups` | (none) | Group, Membership, Affiliation |
| `Wiki` | (none) | Page |
| `GDrive` | (none) | Config, Item, ItemGroup |
| `CustomFields` | (none) | Dynamic JSONB-based field framework |

Module namespaces are defined in files like `app/models/meals.rb` which set `table_name_prefix`.

### Key Patterns

**Authorization (Pundit):** Every controller action must be authorized. `after_action :verify_authorized` (non-index) and `verify_policy_scoped` (index) are enforced in `ApplicationController`. Policies live in `app/policies/` mirroring the model namespace. The `ApplicationPolicy` base class provides helpers like `active_admin?`, `active_cluster_admin?`, `record_tied_to_user_community?`.

**Decorators (Draper):** All view/presentation logic goes in decorators (`app/decorators/`), not models or helpers. `ApplicationDecorator` provides multi-community display helpers like `cmty_prefix`.

**Event System (Wisper):** Models publish events that singleton listeners handle. Listener registration order matters — see `config/initializers/listeners.rb`. Key listeners:
- `Work::MealJobSynchronizer` — syncs meal roles to work jobs
- `Work::MealAssignmentSynchronizer` — syncs meal assignments to work assignments
- `Groups::MembershipMaintainer` — manages group memberships (must run before Mailman/GDrive sync)
- `Billing::AccountManager` — manages billing accounts on household changes

**Lenses:** Filtering/search UI framework in `app/lenses/`. Controllers call `prepare_lenses(:search, :community, ...)` to set up filters.

**Custom Fields:** JSONB-backed extensible fields defined declaratively on models. Community settings are implemented this way.

### Controller Conventions
- `ApplicationController` includes concerns from `ApplicationControllable::*` (RequestPreprocessing, Setters, Loaders, UrlHelpers, Users, Csv)
- `current_community` is set from the subdomain during request preprocessing
- `current_cluster` is the ActsAsTenant current tenant
- Routes use a mix of `namespace` and `scope` — see comments in `config/routes.rb` for why

### Model Conventions
- `ApplicationRecord` provides `alpha_order(*args)` for case-insensitive sorting
- `skip_listener_action` transient attribute suppresses Wisper listener side effects (used in factories/tests)
- Models use `in_community(community)` scopes for community filtering
- `active` scopes filter deactivated records

## Code Style
- Ruby: RuboCop with `standard` gem (Ruby 3.0 config), max line length 110
- Empty methods use `expanded` style (not single-line)
- GuardClause cop is disabled — parallel if/unless blocks are acceptable
- `Style::Documentation` is disabled for controllers, decorators, helpers, policies, serializers

## Tech Stack
- Ruby 3.2.2, Node.js 18.12.1
- Rails 7, PostgreSQL, Redis, Elasticsearch
- Devise + OmniAuth (Google OAuth2) for auth
- Delayed Job for background processing
- esbuild for JS bundling, Stimulus for frontend interactivity
- Bootstrap 3 + Tailwind for CSS
- Thin with SSL in development (https://gatherdev.org:3000)

## Test Organization
- `spec/` mirrors `app/` structure: `models/`, `system/`, `requests/`, `decorators/`, `policies/`, `forms/`, `jobs/`, `mailers/`, `serializers/`, `validators/`, `lenses/`
- Factories in `spec/factories/` organized by module
- Shared support in `spec/support/` (contexts, helpers, matchers)
- System tests use headless Chrome via Selenium
