# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'mess'
set :deploy_to, -> { "/home/tscoho/webapps/rails/mess_#{fetch(:stage)}" }
set :pty, true
set :passenger_restart_with_touch, true
set :repo_url, 'git@github.com:touchstone-cohousing/mess.git'
set :linked_files, fetch(:linked_files, []).push('config/database.yml')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')
set :tmp_dir, '/home/tscoho/tmp'
set :default_env, {
  path: "$HOME/bin:$HOME/webapps/rails/bin:$PATH",
  gem_home: "$HOME/webapps/rails/gems",
  pgoptions: "'-c statement_timeout=0'"
}
set :whenever_identifier, ->{ "#{fetch(:application)}_#{fetch(:stage)}" }

namespace :deploy do
  after :migrate, :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed"
        end
      end
    end
  end
end
