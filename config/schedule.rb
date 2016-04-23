set :output, "#{path}/log/cron_log.log"
env :PATH, ENV['PATH']
env :GEM_HOME, ENV['GEM_HOME']

job_type :enqueue,  "cd :path && RAILS_ENV=:environment bundle exec rake jobs:enqueue[:task] :output"

every 1.hour do
  enqueue %w(
    StatementReminderJob
    MealReminderJob
    ShiftReminderJob
    CookMenuReminderJob
  ).join(",")
end
