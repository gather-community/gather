# frozen_string_literal: true

set(:output, "#{path}/log/cron_log.log")
env(:PATH, ENV["PATH"])
env(:GEM_HOME, ENV["GEM_HOME"])

job_type(:enqueue, "cd :path && RAILS_ENV=:environment bundle exec rake jobs:enqueue[:task] :output")

every 5.minutes do
  enqueue(%w[
    Billing::StatementReminderJob
    Meals::MealReminderJob
    Meals::CookMenuReminderJob
    Meals::CloseMealsJob
    CustomReminderJob
    MailTestJob
  ].join(","))
end

every 1.day, at: "4:30 am" do
  enqueue("CleanupJob")
  enqueue("GDrive::Migration::WebhookRefreshJob")
end
