# frozen_string_literal: true

set :deploy_to, "/home/deploy/gather"
role :app, %w[deploy@198.211.97.159 deploy@157.230.81.136]
role :web, %w[deploy@198.211.97.159 deploy@157.230.81.136]
role :bg, %w[deploy@167.172.152.13]

# This is not the db server. It's just the server we use to run the migrations.
role :db, %w[deploy@198.211.97.159]

set :branch, "master"
set :rails_env, "production"
set :linked_files, fetch(:linked_files, []).push(".rbenv-vars")
