# frozen_string_literal: true

set :deploy_to, "/home/deploy/gather"
role :app, %w[deploy@134.122.120.173]
role :web, %w[deploy@134.122.120.173]
role :db,  %w[deploy@134.122.120.173]
set :branch, "master"
set :rails_env, "production"
set :linked_files, fetch(:linked_files, []).push(".rbenv-vars")
