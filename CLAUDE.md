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
- **Always use `gather_form_for` for new forms** — wraps `simple_form_for` with grid layout, CSS classes, and auto error notification. Options: `width: :full/:normal`, `layout: :narrow_label/:narrower_label/:equal_width/:vertical`.
- **Param allowlisting belongs in the policy** — define a `permitted_attributes` method on the policy and call it from the form model (or controller) rather than using `params.permit(...)` inline. Example: `params.permit(policy(@object).permitted_attributes)`.
- **Use form models for non-trivial forms** — follow the `Calendars::EventForm` pattern (`app/forms/calendars/event_form.rb`): include `ActiveModel::Conversion/Validations`, define `self.model_name` delegating to the AR model, move validations here (not on the model), and implement `save`. The controller passes `params.require(:key)` to the form; the form uses the policy's `permitted_attributes` internally.
- **Field lengths must be enforced in three places using the same constant**: DB column limit (migration), model/form validation (`length: {maximum: CONST}`), and the form field (`maxlength: CONST`).
- **Use `hint:` on `f.input` for field hints** — `f.input :field, hint: "..."` renders a `.hint` span styled with `$text-muted`. Use `<p class="hint">` for section-level hints above a group of fields. Do not use manual `<span class="help-block">` elements.
- **Labels, hints, and select option text belong in YAML** — define them in `config/locales/en/simple_form.yml` under `simple_form.labels.{model}.{field}`, `simple_form.hints.{model}.{field}`, and `simple_form.options.{model}.{field}.{value}`. Simple_form auto-looks them up; no need to pass `label:` or `hint:` in the view. For HTML hints use `{field}_html` key. Select option values go in a constant on the model (e.g., `WANT_SAMPLE_DATA_OPTIONS = %i[true false].freeze`); the human-readable labels go in YAML.
- **Field normalization belongs in form models** — use `extend AttributeNormalizer::ClassMethods` and `normalize_attributes`. Delegate writer methods to the underlying AR object (e.g., `delegate :field=, to: :@model`). Use the default normalizer (strip + blank→nil) for standard strings, `:email` normalizer (strip + downcase + blank→nil) for email fields, and `with: %i[strip blank downcase]` for slug-style fields.
- **Use `Devise.email_regexp` for email format validation** — not `URI::MailTo::EMAIL_REGEXP`. This keeps email validation consistent with Devise's own validation on `User`.
- **Use `I18n.l` for all date/time formatting** — never use `strftime` or `.to_s` for display. In ERB views, `l(date)` is the shorthand. Specify format with `format: :short` or `format: :long`. Date formats are defined in locale files.
- **Index rows use hyperlinks, not button links** — make one or more meaningful fields in the row (e.g. name, title) a hyperlink pointing to the show/review page. Use the action link system (`ActionLink`/`ActionLinkSet` in decorators) for edit/delete operations, not inline button tags.
- **Page-level action buttons use `content_for(:action_links)`** — rendered in the page header. Icons come from Font Awesome 4 via `icon_tag`. Use `btn-primary` for the primary action, `btn-default` for secondary, `btn-danger` for destructive.
  - **Show pages: use the decorator pattern.** Define `show_action_link_set` in the decorator returning an `ActionLinkSet` of `ActionLink` instances. In the view: `<% content_for(:action_links, resource.action_links(:show)) %>`. `ActionLink` checks the policy automatically (`{action}?`) unless you pass `permitted: true/false`. Pass `html: {target: "_blank"}` for extra link HTML attributes, `data: {key: val}` for Stimulus/data attributes, `btn_class: :danger` for destructive actions. Add labels under `action_labels.{model_i18n_key}.{action}` or `action_labels.common.{action}` in `en.yml`.
  - **One-off action links** (e.g. on index pages): use `concat(link_to(icon_tag("icon") << " Label", path, class: "btn btn-..."))` inside the `content_for` block, wrapped in a policy check.
- **Key-value table style for detail displays** — use `<table class="key-value">` for showing record details on show/review pages. Variants: `key-value-narrow` (narrow value column), `key-value-wide` (wide value column), `key-value-full` (full width). First `<td>` is styled as a muted label; second `<td>` holds the value.
- **No "Back" links on show/review pages** — do not add "Back to list" or similar navigation links; this is not a Gather convention.
- **Controller method order** — always put `index` first, followed by `show`, `new`, `edit`, `create`, `update`, `destroy`. Custom actions can go in sensible places after the standard ones.
- **Public controllers must guard shared template policy calls** — when a controller skips `authenticate_user!` (e.g. for a public signup page), shared templates like `_footer.html.erb` and `_nav.html.erb` still render with `current_user = nil`. Any `policy()` call in those templates must be wrapped in `if current_user`, because `ApplicationPolicy#initialize` raises `Pundit::NotAuthorizedError` when user is nil. Always guard: `<% if current_user && policy(Foo.new).action? %>`.
- **Apex-domain controllers override `apex_domain_only`** — controllers whose routes live on the apex domain (no community subdomain) must define `protected def apex_domain_only = true`. This causes `check_subdomain` to call `ensure_apex_domain` (redirecting subdomain requests to apex) instead of rendering 404 when `current_community` is nil.

### Model Conventions
- `ApplicationRecord` provides `alpha_order(*args)` for case-insensitive sorting
- `skip_listener_action` transient attribute suppresses Wisper listener side effects (used in factories/tests)
- Models use `in_community(community)` scopes for community filtering
- `active` scopes filter deactivated records

### Locale Files

Gather uses several locale files under `config/locales/en/`. Each type of string has a canonical home:

**`activerecord.yml`** — the primary source for field labels and custom error messages:
- `activerecord.attributes.{model}.{field}` — field labels for ActiveRecord models (used by simple_form as first lookup); model key uses `/` separator, e.g. `meals/meal`
- `activemodel.attributes.{model}.{field}` — same pattern for non-AR models (e.g. form objects like `calendars/event`)
- `activerecord.models.{model}` — human-readable model names
- `activerecord.errors.models.{model}.attributes.{field}.{error_key}` — custom validation error message overrides

**`simple_form.yml`** — for form presentation strings not covered by activerecord:
- `simple_form.labels.{model}.{field}` — field labels for non-AR forms that have no `activerecord.attributes` entry (e.g. `calendars_export`, `communities_signup`); model key uses `_` separator
- `simple_form.hints.{model}.{field}` — field hint text; use `{field}_html` key for HTML content
- `simple_form.options.{model}.{field}.{value}` — select option labels; simple_form auto-translates symbol collections using this namespace
- `simple_form.placeholders.{model}.{field}` — input placeholder text
- `simple_form.prompts.{model}.{field}` — blank/prompt option for selects

**`en.yml`** — application-wide UI strings:
- `helpers.submit.{action}` or `helpers.submit.{model}.{action}` — submit button labels
- `confirmations.{model}.{action}` — confirm dialog text for destructive actions
- `common.*` — shared strings used across multiple modules
- `errors.messages.*` — global custom error messages

**Module-specific files** (`meals.yml`, `work.yml`, `people.yml`, etc.) — flash messages, page titles, section headers, and other strings belonging entirely to one feature module.

## Email
- **Text-only mailers** — Gather uses plain text email templates only. Do not create `.html.erb` mailer views.

## Testing
- **All new functionality must have test coverage.** Add specs for new models, jobs, mailers, forms, policies, and controllers. Follow existing spec patterns and directory structure.

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
