# frozen_string_literal: true

require "json"
require "fileutils"

class Setup < Thor
  include Thor::Actions

  def self.source_root
    File.expand_path("../templates/setup", __dir__)
  end

  # ---------------------------------------------------------------------------
  # Main entry point
  # ---------------------------------------------------------------------------
  desc "dev", "Interactive setup for Gather development environment"
  def dev
    %w[INT TERM].each do |signal|
      trap(signal) { abort_setup }
    end

    check_dependencies
    check_gems
    check_config_files

    loop do
      show_status
      case main_menu
      when :generate
        generate_config
      when :provision
        provision_database
      when :exit
        break
      end
    end
  rescue EOFError, Interrupt
    abort_setup
  end

  default_task :dev

  private

  def abort_setup
    say
    say "Setup cancelled.", :yellow
    exit 0
  end

  # ---------------------------------------------------------------------------
  # Dependency checking
  # ---------------------------------------------------------------------------
  def check_dependencies
    @deps = {}

    # Ruby
    @deps[:ruby] = true
    @deps[:ruby_version] = RUBY_VERSION

    # Rails
    require "rails/version"
    @deps[:rails] = true
    @deps[:rails_version] = Rails::VERSION::STRING

    # libvips
    if command_exists?("vips")
      version = `vips --version`[/(\d+\.\d+\.\d+)/, 1]
      major, minor = version.split(".").map(&:to_i)
      if major > 8 || (major == 8 && minor >= 8)
        @deps[:libvips] = true
        @deps[:libvips_version] = version
      else
        @deps[:libvips] = false
        @deps[:libvips_version] = "#{version} (too old)"
      end
    else
      @deps[:libvips] = false
      @deps[:libvips_version] = "not found"
    end
  end

  def check_gems
    if system("bundle check > /dev/null 2>&1")
      @deps[:gems] = true
      return
    end

    say
    say "Checking Gems", :bold
    say "Missing gems detected, installing...", :yellow
    say

    if system("bundle install")
      @deps[:gems] = true
      say "Gems installed successfully", :green
      sleep 1
    else
      @deps[:gems] = false
      say
      say "Bundle install failed", :red
      say
      say "Please run 'bundle install' manually and check the errors for guidance."
      exit 1
    end
  end

  def all_deps_ok?
    @deps[:libvips]
  end

  def command_exists?(cmd)
    system("command -v #{cmd} > /dev/null 2>&1")
  end

  # ---------------------------------------------------------------------------
  # Config file checking
  # ---------------------------------------------------------------------------
  CONFIG_FILES = [
    "config/database.yml",
    "config/settings.local.yml",
    "docker-compose.yml"
  ].freeze

  def check_config_files
    @config_status = {}
    CONFIG_FILES.each do |file|
      @config_status[file] = File.exist?(file)
    end
  end

  def existing_configs
    @config_status.select { |_, exists| exists }.keys
  end

  # ---------------------------------------------------------------------------
  # Status display
  # ---------------------------------------------------------------------------
  def show_status
    clear_screen
    say_header
    say

    say "Dependencies", :bold
    say
    say "  ruby        #{status_icon(@deps[:ruby])}  #{@deps[:ruby_version]}"
    say "  rails       #{status_icon(@deps[:rails])}  #{@deps[:rails_version]}"
    say "  libvips     #{status_icon(@deps[:libvips])}  #{@deps[:libvips_version]}"
    say "  gems        #{status_icon(@deps[:gems])}"
    say

    say "Config Files", :bold
    say
    CONFIG_FILES.each do |file|
      status = @config_status[file] ? set_color("exists", :green) : set_color("not found", :white)
      say "  #{file}  #{status}"
    end
    say
  end

  def status_icon(ok)
    ok ? set_color("✓", :green) : set_color("✗", :red)
  end

  def say_header(step: nil)
    title = step ? "Gather Development Setup — #{step}" : "Gather Development Setup"
    say title, :bold
    say "─" * title.length
  end

  def clear_screen
    print "\e[H\e[2J"
  end

  # ---------------------------------------------------------------------------
  # Menus
  # ---------------------------------------------------------------------------
  def main_menu
    options = ["Generate config files"]
    options << "Provision database" if @config_status["docker-compose.yml"]
    options << "Exit"

    choice = select_prompt("Select an action:", options)

    case choice
    when "Generate config files" then :generate
    when "Provision database" then :provision
    when "Exit" then :exit
    end
  end

  def select_prompt(message, options)
    say message
    options.each_with_index do |opt, i|
      say "  #{i + 1}. #{opt}"
    end
    say

    loop do
      input = ask("Enter choice (1-#{options.size}):")
      index = input.to_i - 1
      return options[index] if index >= 0 && index < options.size

      say "Invalid choice, try again", :red
    end
  end

  # ---------------------------------------------------------------------------
  # Config generation
  # ---------------------------------------------------------------------------
  def generate_config
    unless all_deps_ok?
      show_missing_deps
      return
    end

    return unless confirm_overwrite

    collect_postgres_config
    collect_redis_config
    collect_elasticsearch_config
    collect_mailcatcher_config
    collect_oauth_config
    collect_admin_config
    generate_secret_key

    generate_files
    show_completion

    check_config_files
  end

  def show_missing_deps
    say
    say "Cannot generate config: missing dependencies", :red
    say
    say "Please install:"
    say "  - libvips v8.8+" unless @deps[:libvips]
    say
    ask "Press Enter to continue..."
  end

  def confirm_overwrite
    clear_screen
    say_header
    say

    existing = existing_configs
    return true if existing.empty?

    say "Warning: The following files will be overwritten:", :yellow
    existing.each { |f| say "  - #{f}" }
    say
    yes?("Do you want to continue?")
  end

  # ---------------------------------------------------------------------------
  # Config collection
  # ---------------------------------------------------------------------------
  def collect_postgres_config
    clear_screen
    say_header(step: "PostgreSQL")
    say

    source = select_prompt("Source:", ["Use an existing instance", "Run in a container"])

    if source == "Use an existing instance"
      @pg_source = "existing"
      @pg_host = ask("Host:", default: "localhost")
      @pg_port = ask("Port:", default: "5432").to_i
      @pg_user = ask("Username (blank for default):")
      @pg_password = ask("Password (blank for none):", echo: false)
      say
    else
      @pg_source = "docker"
      @pg_host = "postgres"
      @pg_port = 5432
      @pg_user = ask("Username:", default: "gather")
      @pg_password = ask("Password:", default: "gather")
    end
  end

  def collect_redis_config
    clear_screen
    say_header(step: "Redis")
    say

    source = select_prompt("Source:", ["Use an existing instance", "Run in a container"])

    if source == "Use an existing instance"
      @redis_source = "existing"
      @redis_host = ask("Host:", default: "localhost")
      @redis_port = ask("Port:", default: "6379").to_i
    else
      @redis_source = "docker"
      @redis_host = "redis"
      @redis_port = 6379
      say "Redis will run in Docker", :green
    end
  end

  def collect_elasticsearch_config
    clear_screen
    say_header(step: "Elasticsearch")
    say

    source = select_prompt("Source:", ["Use an existing instance", "Run in a container"])

    if source == "Use an existing instance"
      @es_source = "existing"
      @es_host = ask("Host:", default: "localhost")
      @es_port = ask("Port:", default: "9200").to_i
    else
      @es_source = "docker"
      @es_host = "elasticsearch"
      @es_port = 9200
      say "Elasticsearch will run in Docker", :green
    end
  end

  def collect_mailcatcher_config
    clear_screen
    say_header(step: "Mailcatcher")
    say
    say "Mailcatcher will run in Docker", :green
    sleep 1
  end

  def collect_oauth_config
    clear_screen
    say_header(step: "Google OAuth")
    say

    say "Create an OAuth client at: https://console.cloud.google.com/apis/credentials"
    say
    say "Configure with:"
    say "  Authorized JS origins:    https://gatherdev.org:3000"
    say "  Authorized redirect URIs: https://gatherdev.org:3000/users/auth/google_oauth2/callback"
    say

    @google_client_id = ask("Client ID:")
    @google_client_secret = ask("Client Secret:", echo: false)
    say

    if @google_client_id.empty? || @google_client_secret.empty?
      say "OAuth credentials not provided - you'll need to add them manually later", :yellow
      @google_client_id = "REPLACE_ME" if @google_client_id.empty?
      @google_client_secret = "REPLACE_ME" if @google_client_secret.empty?
    end
  end

  def collect_admin_config
    clear_screen
    say_header(step: "Admin User")
    say

    say "Enter details for the initial admin user:"
    say

    @admin_fname = ask("First name:")
    @admin_lname = ask("Last name:")
    @admin_email = ask("Email:")
  end

  def admin_config_present?
    @admin_fname && @admin_lname && @admin_email &&
      !@admin_fname.empty? && !@admin_lname.empty? && !@admin_email.empty?
  end

  def generate_secret_key
    @secret_key = `openssl rand -hex 64`.chomp
  end

  # ---------------------------------------------------------------------------
  # File generation
  # ---------------------------------------------------------------------------
  def generate_files
    clear_screen
    say_header(step: "Generating Files")
    say

    say "==> Generating config/database.yml...", :green
    template "database.yml.erb", "config/database.yml", force: true

    say "==> Generating config/settings.local.yml...", :green
    template "settings.local.yml.erb", "config/settings.local.yml", force: true

    say "==> Generating docker-compose.yml...", :green
    template "docker-compose.yml.erb", "docker-compose.yml", force: true
  end

  def show_completion
    say
    say "Setup Complete!", [:bold, :green]
    say

    say "Generated files:"
    say "  - config/database.yml"
    say "  - config/settings.local.yml"
    say "  - docker-compose.yml"
    say

    say "Next step:"
    say "  Select 'Provision database' from the main menu to start services and set up the database."
    say

    ask "Press Enter to continue..."
  end

  # ---------------------------------------------------------------------------
  # Database provisioning
  # ---------------------------------------------------------------------------
  def provision_database
    collect_admin_config unless admin_config_present?

    clear_screen
    say_header(step: "Provisioning Database")
    say

    # Start docker compose services
    say "==> Starting Docker services...", :green
    unless system("docker compose up -d")
      say "Failed to start Docker services", :red
      ask "Press Enter to continue..."
      return
    end

    # Wait for postgres to be healthy
    say "==> Waiting for PostgreSQL to be ready...", :green
    unless wait_for_postgres
      say "PostgreSQL failed to become healthy", :red
      ask "Press Enter to continue..."
      return
    end

    # Create and setup database
    say "==> Creating database...", :green
    unless system("rake db:create")
      say "Failed to create database", :red
      ask "Press Enter to continue..."
      return
    end

    say "==> Loading schema...", :green
    unless system("rake db:schema:load")
      say "Failed to load schema", :red
      ask "Press Enter to continue..."
      return
    end

    # Create admin user and seed data
    say "==> Creating cluster with admin user...", :green
    cmd = "rake db:new_cluster " \
          "ADMIN_FNAME=\"#{@admin_fname}\" " \
          "ADMIN_LNAME=\"#{@admin_lname}\" " \
          "ADMIN_EMAIL=\"#{@admin_email}\" " \
          "SUPER_ADMIN=y"

    unless system(cmd)
      say "Failed to create cluster", :red
      ask "Press Enter to continue..."
      return
    end

    say
    say "Database provisioned successfully!", [:bold, :green]
    say
    say "You can now start the application:"
    say "  1. Start the server:         bin/dev"
    say "  2. Start background jobs:    bin/delayed_job run"
    say
    say "Access the app at:      https://gatherdev.org:3000"
    say "Mailcatcher UI at:      http://localhost:1080"
    say

    ask "Press Enter to continue..."
  end

  def wait_for_postgres(timeout: 60)
    start_time = Time.now
    loop do
      # Check if postgres container is healthy
      result = `docker compose ps postgres --format json 2>/dev/null`
      if result.include?('"Health":"healthy"') || result.include?('health: healthy')
        return true
      end

      # Also try direct health check
      if system("docker compose exec -T postgres pg_isready -U #{@pg_user || 'gather'} > /dev/null 2>&1")
        return true
      end

      if Time.now - start_time > timeout
        return false
      end

      sleep 2
      print "."
    end
  end
end
