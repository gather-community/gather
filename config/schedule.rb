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

every 1.day, at: "2:30 am" do
  enqueue("Subscription::SyncAllJob")
end

every 1.day, at: "2:45 am" do
  enqueue("Subscription::RefreshPricingDataJob")
end

every 1.day, at: "3:00 am" do
  enqueue("Communities::InactivityWarningJob")
end

every 1.day, at: "3:15 am" do
  enqueue("Work::ArchivePeriodsJob")
end

every 1.day, at: "4:30 am" do
  enqueue("CleanupJob")
  enqueue("GDrive::Migration::WebhookRefreshJob")
end
