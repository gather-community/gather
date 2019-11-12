# frozen_string_literal: true

# config valid only for current version of Capistrano
lock "3.11.0"

abort("Please set REV environment variable to indicate the git revision you want to deploy") unless ENV["REV"]
set :branch, ENV["REV"]

set :application, "gather"
set :pty, true
set :repo_url, "git@github.com:sassafrastech/gather.git"
set :linked_files, fetch(:linked_files, []).push("config/database.yml")
set :linked_dirs, fetch(:linked_dirs, []).push("log", "tmp/pids", "tmp/cache", "tmp/sockets",
                                               "vendor/bundle", "public/system")
set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

# Ensure specified revision is pushed to remote.
branch_url = "https://raw.githubusercontent.com/sassafrastech/gather/#{fetch(:branch)}"
if `curl -s -o /dev/null -w "%{http_code}" #{branch_url}/VERSION` != "200"
  abort("Error accessing REV #{ENV['REV']}. Is it pushed?")
end

# Defining a custom delayed job restart task because we manage it with systemctl.
# This is allowed because we added `deploy ALL=(ALL) NOPASSWD: /bin/systemctl restart delayed-job.service`
# to the sudoers file.
namespace :delayed_job do
  task :restart do
    on roles(:app) do
      execute :sudo, "/bin/systemctl restart delayed-job.service"
    end
  end
end

after "deploy:published", "delayed_job:restart"
