set :output, "#{path}/log/cron_log.log"
env :PATH, ENV['PATH']
env :GEM_HOME, ENV['GEM_HOME']

job_type :enqueue,  "cd :path && RAILS_ENV=:environment bundle exec djc-enqueue :task :output"

every 1.hour do
  enqueue "MealReminderJob ShiftReminderJob"
end

every 1.day, at: "4:30 am" do
  enqueue "StatementReminderJob"
end
