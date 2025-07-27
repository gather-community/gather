# frozen_string_literal: true
set :deploy_to, "/home/deploy/gather"

role :app, %w[deploy@10.136.121.104 deploy@10.136.121.106 deploy@10.136.121.112]
role :web, %w[deploy@10.136.121.104 deploy@10.136.121.106 deploy@10.136.121.112]
role :bg, %w[deploy@10.136.121.113]

# This is not the db server. It's just the server we use to run the migrations.
role :db, %w[deploy@10.136.121.104]

set :branch, "develop"
set :rails_env, "production"
set :linked_files, fetch(:linked_files, []).push(".rbenv-vars")
