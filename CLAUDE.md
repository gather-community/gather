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

### Verifying a Clean Boot Before Deploying
Development already uses `config.eager_load = true`, so boot errors surface locally. Before deploying a branch that touches gems, initializers, or models, run these three checks:
```bash
RAILS_ENV=development bundle exec rails runner "puts 'ok'"  # Full boot check
RAILS_ENV=development bundle exec rake assets:precompile    # Asset pipeline
bin/dev                                                     # Full dev server
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

### Taking Screenshots

The dev server must be running first (`bin/dev` won't stay up in the background because foreman's esbuild watcher requires stdin). Start just the web server and build JS assets separately:

```bash
yarn build                          # One-off JS build (no watch)
bundle exec thin start --ssl --ssl-key-file config/ssl/gatherdev.org.key \
  --ssl-cert-file config/ssl/gatherdev.org.crt &   # Rails on https://foo.gatherdev.org:3000
```

Screenshots use the Selenium container (`gather-selenium`) via a Ruby script with `selenium-webdriver`. The container shares `vibrant_borg`'s network namespace; reach it from this container at `172.18.0.3:4444`. The app is at `172.18.0.2`. Use `--host-resolver-rules` to make Chrome resolve both apex and wildcard subdomains to `172.18.0.2`.

```ruby
# tmp/screenshot.rb — adapt as needed
require 'selenium-webdriver'

SELENIUM_URL  = 'http://172.18.0.3:4444'
APP_IP        = '172.18.0.2'
APEX_URL      = 'https://gatherdev.org:3000'
COMMUNITY_URL = 'https://foo.gatherdev.org:3000'  # adjust community slug
EMAIL         = 'user@example.com'                 # set a known password first (see below)
PASSWORD      = 'testtest1'

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--ignore-certificate-errors')
options.add_argument("--host-resolver-rules=MAP *.gatherdev.org #{APP_IP},MAP gatherdev.org #{APP_IP}")
options.add_argument('--window-size=1280,900')

driver = Selenium::WebDriver.for(:remote, url: SELENIUM_URL, options: options)
wait   = Selenium::WebDriver::Wait.new(timeout: 10)

def full_page_screenshot(driver, path)
  height = driver.execute_script("return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)")
  driver.manage.window.resize_to(1280, height)
  sleep 0.5
  driver.save_screenshot(path)
  driver.manage.window.resize_to(1280, 900)
end

begin
  driver.navigate.to("#{APEX_URL}/people/users/sign-in")
  wait.until { driver.find_element(id: 'user_email') }
  driver.find_element(id: 'user_email').send_keys(EMAIL)
  driver.find_element(id: 'user_password').send_keys(PASSWORD)
  driver.find_element(css: 'input[type=submit]').click
  sleep 3

  driver.navigate.to("#{COMMUNITY_URL}/some/path")
  sleep 4
  full_page_screenshot(driver, 'tmp/screenshot.png')
ensure
  driver.quit
end
```

To set a known password for any user before running the script:

```ruby
# bundle exec rails runner this snippet
CH.tenant(1)
u = User.find_by(email: 'user@example.com')
u.password = u.password_confirmation = 'testtest1'
u.skip_reconfirmation!
u.save!(validate: false)
```

Run the script with `bundle exec ruby tmp/screenshot.rb`. Output PNGs go in `tmp/` (gitignored).

### Adding Screenshots to a PR

GitHub's drag-and-drop uploads go to its `user-attachments` CDN through a browser-only, session-authenticated endpoint — there is **no public API for it**, so screenshots can't be attached that way from here. Don't ask the user to drag files in; use this instead (the repo is public, so raw URLs render):

1. Crop the dead space off the full-page screenshot — `vips` is installed:

```bash
vips crop tmp/shot.png tmp/pr_shot.png 0 0 1280 680   # args: x y width height
```

2. Commit the image and push. `tmp/` is gitignored, so force-add:

```bash
git add -f tmp/pr_shot.png
git commit -m "Add PR screenshot (temporary)"
git push
```

3. Embed it in the PR body using a **SHA-pinned** raw URL with that commit's SHA:

```
https://raw.githubusercontent.com/gather-community/gather/<SHA>/tmp/pr_shot.png
```

4. Delete the image in a follow-up commit and push.

The URL keeps rendering after the delete because the blob still exists at the pinned SHA, so the PR shows the images while the merged tree stays clean — only the blobs remain in history (a few hundred KB). **Pin to the SHA, not a branch name**; a branch-based URL breaks the moment the file is deleted.

## Architecture

### Multi-Tenancy Hierarchy

`Cluster` → `Community` → `Household` → `User`

- **Cluster** is the ActsAsTenant tenant. All queries are automatically scoped to the current cluster.
- **Community** scoping is handled by policies and controllers, not ActsAsTenant.
- Users have global roles: `super_admin`, `cluster_admin`, `admin`, plus community-specific roles like `biller`, `meals_coordinator`, `work_coordinator`.

### Feature Modules

Code is organized by feature domain. Each module has its own models, controllers, decorators, policies, jobs, and mailers under matching namespaces:

| Module         | Table Prefix | Key Models                                    |
| -------------- | ------------ | --------------------------------------------- |
| `Meals`        | `meal_`      | Meal, Signup, Assignment, Formula, Role, Type |
| `Work`         | `work_`      | Job, Shift, Period, Assignment                |
| `Calendars`    | `calendar_`  | Calendar, Event, Protocol, Group              |
| `Billing`      | `billing_`   | Account, Statement, Transaction, Template     |
| `People`       | (none)       | User, Household, MemberType, Memorial         |
| `Groups`       | (none)       | Group, Membership, Affiliation                |
| `Wiki`         | (none)       | Page                                          |
| `GDrive`       | (none)       | Config, Item, ItemGroup                       |
| `CustomFields` | (none)       | Dynamic JSONB-based field framework           |

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

**Feature Flags:** Unshipped features are gated by the `FeatureFlag` model (not tenant-scoped; rows are created/toggled manually, e.g. in the console). Call it **directly** from controllers and templates — don't wrap it in a helper:

```ruby
FeatureFlag.lookup("messaging").on?(current_user)
```

- Use `lookup(name)`, not `find_by(name:)` — it returns an unsaved, default-**off** flag when the row doesn't exist, so a feature is off everywhere until you explicitly turn it on (and there's no nil to guard).
- **Always pass `current_user`.** With the default `interface: "basic"` the flag is a global on/off and the user is ignored; switching a flag to `interface: "user"` makes it check per-user membership (`feature_flag_users`), which lets you enable a feature for just yourself in production. Passing the user means that switch needs no code change. (`on?` raises if a `"user"`-interface flag gets no user.)
- Gate **both** the UI and the endpoints — hiding a link doesn't stop a direct request. Also skip any expensive work (e.g. external API calls) the hidden feature would trigger.
- Don't gate inbound webhooks/background reconciliation: turning a flag off shouldn't strand data that already exists.
- Specs that exercise a flagged feature must turn it on: `create(:feature_flag, name: "messaging", status: true)`.

Existing flags: `messaging`, `gdrive`, `restrictions`.

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

### Adding a New Model

When introducing a new model, follow the established conventions:

- **Namespace by feature module.** Put the model under its module namespace (e.g. `app/models/messaging/account.rb`) and add a `app/models/<module>.rb` defining `table_name_prefix` (e.g. `"messaging_"`). Only set `self.table_name = "..."` when overriding the prefix (as `Billing` does).
- **Tenant scoping is mandatory.** Every model must declare `acts_as_tenant :cluster`, and its migration must add `cluster_id` (`null: false`, foreign key). This is enforced by the wholesome specs below.
- **Money** is stored as an integer `amount_cents` column (newer models, e.g. `Messaging::Transaction`) or `decimal(10, 2)` (older Billing models) — match the surrounding feature.
- **Add a factory** under `spec/factories/<module>/` and a model spec.
- **Decorators/policies** come only when the model becomes user-facing.

**Three "wholesome" specs iterate over every model — a new model must satisfy all three (or be added to the relevant allowlist):**

- [spec/models/tenancy_spec.rb](spec/models/tenancy_spec.rb) — every model must have `acts_as_tenant`. Allowlist (`ALLOWLISTED_CLASSES`) only for genuinely non-tenant models.
- [spec/models/utils/generators/main_generator_spec.rb](spec/models/utils/generators/main_generator_spec.rb) — every model must get at least one record from sample-data generation, **or** be added to `NO_SAMPLE_DATA_CLASSES` (use this for models created on demand, e.g. via a webhook).
- [spec/models/community_deletion_spec.rb](spec/models/community_deletion_spec.rb) — every tenant model needs a factory call in the setup and must cascade to zero rows when a community is destroyed (wire `dependent: :destroy` from `Community` and/or its parent), **or** be added to `EXEMPT_MODELS`. Prefer wiring the cascade so deletion is actually tested.

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
- `common.*` — shared strings used across multiple strings used across multiple modules
- `errors.messages.*` — global custom error messages

**Module-specific files** (`meals.yml`, `work.yml`, `people.yml`, etc.) — flash messages, page titles, section headers, and other strings belonging entirely to one feature module.

## Email

- **Text-only mailers** — Gather uses plain text email templates only. Do not create `.html.erb` mailer views.

## Testing

- **All new functionality must have test coverage.** Add specs for new models, jobs, mailers, forms, policies, and controllers. Follow existing spec patterns and directory structure.
- **System tests require headless Chrome.** See the [Selenium Docker service](#headless-chrome-for-system-tests) section below.
- **Run individual or small numbers of specs locally; use CI for full suite runs.** When fixing a specific failure, run the affected file/line with `bundle exec rspec spec/path/to/spec.rb:42` locally to confirm it passes before pushing — this avoids burning a ~28 min CI cycle on a fix that doesn't work. Only push to CI when you need the full suite run (e.g. after a Rails upgrade or broad refactor). Non-browser specs (model, request, job, mailer) run fine locally; system specs require headless Chrome (see below).
- **Replicate CI failures locally before iterating.** Add a diagnostic assertion with a descriptive failure message (e.g. `expect(count).to eq(1), "Expected 1, got #{count}. Details: #{things.inspect}"`) to extract values that aren't visible in a normal failure.

## Handling Dependabot Batches

**Trigger phrase:** when the user says **"combine the dependabot PRs"** (or similar — "batch the dependabot updates", "deal with all the dependabot PRs at once"), run this full procedure end to end: combine the open updates into one branch, open a PR, and poll CI per the section below. Don't ask for confirmation on the mechanics — just do it, then report the result.

Merging dependabot branches one at a time is slow (each merge rebases all the others) and merging them together conflicts on lockfiles. Instead, **rebuild the bumps on top of current `develop` and regenerate the lockfiles** — never merge the dependabot branches themselves, because they're often cut from an older `develop` and carry unrelated drift.

1. **List the open updates:** `gh pr list --author "app/dependabot" --limit 100 --json number,title`.
2. **Branch from current develop:** `git switch -c combined-dependabot origin/develop` (after `git fetch origin`).
3. **Decide what to include.** Exclude stale/superseded branches: bumps for a major version line you're no longer on (e.g. Rails 7.0.x security branches when you're on 8.1), and older duplicates when a newer bump for the same package exists (take the newest, let the older PR auto-close). When two branches target the same package, only the newest goes in.
4. **Get each branch's intended bump** so you apply it faithfully: `git diff origin/develop origin/dependabot/<branch> -- Gemfile` (or `package.json`). Ignore any hunks that are just develop drift (e.g. an unrelated gem being removed/added) — apply only the dependency line the PR is actually about.
5. **Apply the version bumps directly to the live manifests** (`Gemfile`, `package.json`) on the new branch — edit the constraint lines, do not merge branches.
6. **Regenerate lockfiles cleanly:** `bundle install` then `yarn install`. For a **transitive** gem bump (one not named in `Gemfile`, e.g. `jwt`), bump it explicitly with `bundle update <gem> --conservative`. Note `~>` constraints may resolve to a newer patch/minor than the dependabot PR named (e.g. `~> 0.81` landing 0.82.0) — that's fine.
7. **Research breaking changes for every major (and risky minor) bump, then check each against our codebase.** For each bump that crosses a major version (or a 0.x→higher jump that spans many releases), read the gem's official CHANGELOG/release notes and list the breaking changes. Spawn one research agent per gem so they run in parallel. Then verify each potentially-impactful change against our actual code — grep for the affected API, config, or option — rather than assuming it does or doesn't apply. Things to watch for: **dropped transitive dependencies that become soft/optional** (e.g. image_processing 2.0 dropped `mini_magick`/`ruby-vips` from its deps — we use the `:vips` processor, so `ruby-vips` had to be added to the `Gemfile` explicitly or ActiveStorage variants break at runtime), changed default behavior, removed/renamed options, dropped Ruby-version support, and changed bind/env defaults. Apply any required follow-up manifest changes (e.g. adding a now-explicit dependency) and re-run `bundle install`. Summarize the findings and the action taken for each gem in the PR body.
8. **Sanity-check before pushing** (cheap, catches the worst of major bumps before a ~28 min CI cycle): `RAILS_ENV=development bundle exec rails runner "puts 'ok'"` (boot), `yarn build` (esbuild), and for type-only bumps a `tsc` pass. Type checking is **not** in CI, so it won't gate the build — but still surface any new errors a major `@types/*` bump introduces.
9. **Verify only the expected files changed** (`Gemfile`, `Gemfile.lock`, `package.json`, `yarn.lock` — plus any deliberate follow-up like an added gem line) via `git status --short` — no drift leaked in.
10. **Commit, push, open one PR.** In the PR body, list every bump with its PR number and add `Closes #…` for each, plus the breaking-change review from step 7 (per-gem: what changed, whether it affects us, action taken). Dependabot auto-closes its own PRs once it sees the dependency updated on `develop` after merge (including superseded duplicates), so the individual PRs clean themselves up.

## Missing SSH Key When Pushing

The SSH key lives on the Mac host and is forwarded into the devcontainer via VSCode's agent socket — it is not in the container's `~/.ssh`. If a push fails with `Permission denied (publickey)` and `ssh-add -l` reports "The agent has no identities" (typical after the host reboots), **ask the user to run a `git pull` on the host**. That reloads the key into the host's agent, and the forwarded agent picks it up immediately — no container restart needed. Don't work around it by reconfiguring git credential helpers or fiddling with keys in the container.

## Polling CI After Opening a PR

**Always poll CI after opening a new PR (or pushing fixes to one), and keep going until the build is green or the only failures are known flappers.** Do not declare success or walk away while checks are pending or red.

- **Poll every 5 minutes.** The Gather suite takes ~28–30 min. Use a background watcher (`gh pr checks <pr> --watch --interval 300`) so you're notified on completion; relaunch it if the watch window lapses while checks are still pending.
- **On failure, investigate before re-running.** Pull the failed job log (`gh run view --job <id> --log-failed`), identify the failing spec, and reproduce locally (`bundle exec rspec <file>:<line>`, several times for system specs). Fix real failures and push.
- **Only treat a failure as a flapper with evidence — never assume.** A failure counts as a known flapper only if you can point to prior occurrences: it passes on local re-run **and** there's a documented history of the same flap (git log/blame referencing it, an existing skip/retry annotation, a prior CI run, or a tracking issue). `StaleElementReferenceError` and other Selenium timing errors in system specs are common flap shapes, but the shape alone is not evidence — confirm the specific spec has flapped before. **Do not hallucinate a flapper to dismiss a red build.** If you can't substantiate it, treat the failure as real.
- **Re-running CI:** the integration token may lack permission to `gh run rerun`/`gh run cancel` (403 "Resource not accessible by integration"). When it does, re-trigger with an empty commit (`git commit --allow-empty`) and tell the user they'll need to cancel runs from the GitHub Actions UI themselves.
- **Don't modify an unrelated pre-existing flake to make a PR green** — especially on a narrow PR like a dependency bump. Re-run CI and note the flake instead.

## Code Style

- Ruby: RuboCop with `standard` gem (Ruby 3.0 config), max line length 110
- Empty methods use `expanded` style (not single-line)
- GuardClause cop is disabled — parallel if/unless blocks are acceptable
- `Style::Documentation` is disabled for controllers, decorators, helpers, policies, serializers

## Announcing Features on the Discourse Forum

When a notable feature ships, we might want to post an announcement to the Gather support forum (https://support.forum.gather.coop) using `bin/post_announcement`. Posts appear as the `Gather_Bot` user.

Write a small wrapper script to `tmp/` (gitignored) and tell user to run `bash tmp/run_announcement.sh` in their own shell.

**Required env vars** (set in your host shell):

- `DISCOURSE_BASE_URL` — e.g. `https://support.forum.gather.coop`
- `DISCOURSE_BOT_API_KEY`
- `DISCOURSE_BOT_USERNAME`
- `DISCOURSE_ANNOUNCEMENTS_CATEGORY_ID`

**Draft guidelines:**

- **Titles end with an exclamation mark** unless it really doesn't make sense
- Audience is technically inclined but not necessarily software engineers — they know their way around a computer and are the Gather expert in their community; don't over-explain, but don't assume deep technical knowledge either
- Warm but concise — 2–3 short paragraphs max
- Lead with what changed and why it matters to them; skip implementation detail
- Posts appear from `Gather_Bot`, so write in first-person plural ("We're happy to share...")
- Always end the post body with: `*This post was by the Gather Bot, a bot that helps us announce new features and updates to Gather!*`

**Including a screenshot:**

To include a screenshot, ask the user to:
1. Take the screenshot with **Cmd+Shift+4**
2. Drag the resulting file into the VSCode file navigator at the repo root
3. Tell you the filename

Once the file is in the repo root, upload it to Discourse, embed it in the post, then **delete the file** after the script runs successfully.

If the user provides a screenshot as a local file (e.g. `Untitled.jpg` in the repo root), upload it to Discourse first, then embed the URL in the post body. Add this to the wrapper script before calling `bin/post_announcement`:

```bash
IMAGE_PATH="$(cd "$(dirname "$0")/.." && pwd)/Untitled.jpg"

echo "Uploading screenshot..."
UPLOAD_RESPONSE=$(curl -s -X POST "$DISCOURSE_BASE_URL/uploads.json" \
  -H "Api-Key: $DISCOURSE_BOT_API_KEY" \
  -H "Api-Username: $DISCOURSE_BOT_USERNAME" \
  -F "files[]=@$IMAGE_PATH" \
  -F "type=composer")

IMAGE_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.url // empty')

if [[ -z "$IMAGE_URL" ]]; then
  echo "Image upload failed:" >&2
  echo "$UPLOAD_RESPONSE" | jq '.' >&2
  exit 1
fi
```

Then embed in the body with `![$TITLE]($IMAGE_URL)`. After the post succeeds, delete the screenshot file from the repo root with `rm`.

## Error Handling

**Never swallow exceptions silently.** If you write a `rescue` block, you must either re-raise or report to Sentry via `Gather::ErrorReporter.instance.report(e, data: {...})`. Always check with the user before suppressing an error without Sentry reporting.

The only exception: errors that are part of normal expected operation (e.g. `ActiveRecord::RecordNotFound` in a `find_by` flow where nil is the expected fallback) do not need Sentry. If you're unsure whether an error is "normal operation", ask.

## Upgrading Rails

When upgrading Rails to a new version, always read the official upgrade guide at https://guides.rubyonrails.org/upgrading_ruby_on_rails.html before making changes. The guide covers breaking changes, removed features, new defaults, and required config updates for each version step.

**Do not bump `config.load_defaults` in `config/application.rb` as part of the gem version bump.** New framework defaults must be adopted one at a time — run `bin/rails app:update` to generate `config/initializers/new_framework_defaults_X_Y.rb`, then enable and test each default individually before removing the override. Bumping `load_defaults` all at once silently activates many behavior changes and makes it impossible to bisect regressions.

**When running `bin/rails app:update`, only keep the new `config/initializers/new_framework_defaults_X_Y.rb` file.** The command will prompt to overwrite many existing files (application.rb, environment configs, puma.rb, public error pages, bin scripts, etc.) — decline all overwrites. Use `git checkout -- <files>` to restore anything that was accidentally overwritten.

**After generating the new framework defaults file, read all the commented-out options, summarize each one for the user (what it does and any risk), and ask which ones they'd like to enable.**

## Secrets Management

Gather does **not** use Rails encrypted credentials. Secrets are managed in two places:

- **Local dev**: `config/settings.local.yml` (gitignored). Generated from `config/templates/settings.local.yml` by `mise conf`. Add local overrides and secrets here. Access via `Settings.some_key`.
- **Production**: a script in `.bashrc` on each web and worker server pulls secrets from a text file on the deploy server and exports them as environment variables. Secrets use the `SETTINGS__` prefix (e.g. `SETTINGS__SOME__NESTED__KEY=value`), which the `config` gem maps to `Settings.some.nested.key`.

When adding a new secret:
1. Add it to your local `config/settings.local.yml`
2. Document it with a blank value in `config/templates/settings.local.yml` (this file is checked in)
3. Add the corresponding `SETTINGS__*` env var to the deploy server's secrets text file

Active Record Encryption keys follow the same pattern — set them as `SETTINGS__ACTIVE_RECORD_ENCRYPTION__PRIMARY_KEY`, `SETTINGS__ACTIVE_RECORD_ENCRYPTION__DETERMINISTIC_KEY`, and `SETTINGS__ACTIVE_RECORD_ENCRYPTION__KEY_DERIVATION_SALT` in the deploy server's secrets file.

## Tech Stack

- Ruby 3.2.2, Node.js 18.12.1
- Rails 8.1, PostgreSQL, Redis, Elasticsearch
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

## Headless Chrome for System Tests

System specs (`js: true`) use headless Chrome via Selenium. On macOS the locally-installed Chrome is used automatically. On Linux (the dev container), `SELENIUM_REMOTE_URL` is set as a container env var pointing at a `seleniarm/standalone-chromium` container, so `bundle exec rspec` works normally — no special wrapper needed.

The Selenium container is started automatically when the devcontainer starts (via `postStartCommand`) using `--network=container:<devcontainer-id>`, which **shares the devcontainer's network namespace**. This means:
- `*.gatherdev.org` wildcard DNS (configured on the Mac host) resolves to `127.0.0.1` inside Chrome, reaching Capybara's test server
- VCR already ignores `localhost:4444` (the Selenium WebDriver endpoint)

**Why shared network namespace instead of a docker-compose service?** The Mac's wildcard DNS for `*.gatherdev.org` resolves to `127.0.0.1`. In a regular docker-compose service, `127.0.0.1` is that container's own loopback — Capybara's test server isn't there. Sharing the devcontainer's network namespace means Chrome and the test server share the same `127.0.0.1`.

**Why not `selenium-manager` auto-download?** Chrome for Testing publishes `mac-arm64` (macOS) but not `linux-arm64`. The Ruby gem's Linux `selenium-manager` binary is also x86_64-only and downloads the wrong architecture on Apple Silicon devcontainers.

### Select2 Testing (`spec/support/helpers/system_spec_helpers.rb`)

Select2 v4 appends its floating dropdown to `document.body` via `AttachBody`. This means the dropdown lives outside any `within` scope. The `with_top_level_scope` helper works around this by pushing `nil` onto Capybara's internal `@scopes` stack, temporarily resetting to document root — the same mechanism used by `within_window`.

Key behaviors:

- **Single-select**: opening appends `.select2-search--dropdown .select2-search__field` to body. Use `execute_script("$('#id').select2('open')")` to open, then `find(".select2-search--dropdown .select2-search__field").set(value)` to type.
- **Multiple-select**: uses inline search (`.select2-search__field` on the span), no dropdown search field. After clicking a result, the dropdown stays open — close it with `find("body").click`.
- One open single-select creates **two** `.select2-container--open` elements (inline container + floating dropdown). This is normal.
