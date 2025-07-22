# frozen_string_literal: true
set :deploy_to, "/home/deploy/gather"

role :app, %w[deploy@10.136.121.104 deploy@10.136.121.106] #deploy@10.136.121.112]
role :web, %w[deploy@10.136.121.104 deploy@10.136.121.106] #deploy@10.136.121.112]
role :bg, %w[deploy@10.136.121.113]

# This is not the db server. It's just the server we use to run the migrations.
role :db, %w[deploy@10.136.121.104]

# role :app, %w[deploy@198.211.97.159 deploy@157.230.81.136] #deploy@161.35.116.42]
# role :web, %w[deploy@198.211.97.159 deploy@157.230.81.136] #deploy@161.35.116.42]
# role :bg, %w[deploy@167.172.152.13]

# # This is not the db server. It's just the server we use to run the migrations.
# role :db, %w[deploy@198.211.97.159]

set :branch, "develop"
set :rails_env, "production"
set :linked_files, fetch(:linked_files, []).push(".rbenv-vars")
