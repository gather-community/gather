# frozen_string_literal: true

# Sends notifications for reminders that use the Reminder/ReminderDelivery system.
# Runs every hour.
class CustomReminderJob < ReminderJob
  # In case the job hasn't run for awhile, how old is too old to deliver?
  EXPIRY_TIME = 3.hours

  def perform
    ActsAsTenant.without_tenant do
      scheduled_deliveries_by_community.each do |community, deliveries|
        with_community(community) do
          deliveries.each(&:deliver!)
        end
      end
    end
  end

  private

  def scheduled_deliveries_by_community
    ReminderDelivery
      .where("deliver_at <= ?", Time.zone.now)
      .where("deliver_at >= ?", Time.zone.now - EXPIRY_TIME)
      .where(delivered: false)
      .includes(eager_loads)
      .group_by(&:community)
  end

  # Returns eager loads that may be needed by any of the ReminderDelivery subclasses or to
  # get to the related community object.
  def eager_loads
    [:reminder,
     shift: {assignments: :user, job: {period: :community}},
     meal: [:community, assignments: %i[user role]]]
  end
end
