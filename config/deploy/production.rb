# frozen_string_literal: true

set :deploy_to, "/u/apps/gather"
role :app, %w[deploy@34.195.234.136]
role :web, %w[deploy@34.195.234.136]
role :db,  %w[deploy@34.195.234.136]
set :rails_env, "production"
set :rbenv_custom_path, "/opt/rbenv"
set :linked_files, fetch(:linked_files, []).push(".rbenv-vars")
