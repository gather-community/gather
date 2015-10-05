set :output, "#{path}/log/cron_log.log"
env :PATH, ENV['PATH']
env :GEM_HOME, ENV['GEM_HOME']

job_type :enqueue,  "cd :path && RAILS_ENV=:environment bundle exec djc-enqueue :task :output"

every 1.minute do
  enqueue "MealReminderJob"
end
