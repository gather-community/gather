# frozen_string_literal: true

# Sends notifications for reminders that use the Reminder/ReminderDelivery system.
# Should run frequently because reminders can be set for any time, not just on the hour.
class CustomReminderJob < ReminderJob
  def perform
    ActsAsTenant.without_tenant do
      clean_old_deliveries
      scheduled_deliveries_by_community.each do |community, deliveries|
        with_cluster(community.cluster) do
          deliveries.each(&:deliver!)
        end
      end
    end
  end

  private

  def clean_old_deliveries
    ReminderDelivery.too_old.delete_all
  end

  def scheduled_deliveries_by_community
    ReminderDelivery.where("deliver_at <= ?", Time.zone.now).includes(eager_loads).group_by(&:community)
  end

  # Returns eager loads that may be needed by any of the ReminderDelivery subclasses or to
  # get to the related community object.
  def eager_loads
    [:reminder,
     {shift: {assignments: :user, job: {period: :community}},
      meal: [:community, {assignments: %i[user role]}]}]
  end
end
