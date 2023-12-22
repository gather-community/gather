# frozen_string_literal: true

set :deploy_to, "/home/deploy/gather"
role :app, %w[deploy@143.244.212.80]
role :web, %w[deploy@143.244.212.80]
role :db, %w[deploy@143.244.212.80]
set :branch, "master"
set :rails_env, "production"
set :linked_files, fetch(:linked_files, []).push(".rbenv-vars")
