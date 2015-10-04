set :output, "#{path}/log/cron_log.log"

job_type :enqueue,  "cd :path && RAILS_ENV=:environment bundle exec djc-enqueue :task :output"

every 1.minute do
  enqueue "MealReminderJob"
end
