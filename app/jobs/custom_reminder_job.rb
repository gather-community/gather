# frozen_string_literal: true

# Sends notifications for reminders that use the Reminder/ReminderDelivery system.
# Should run frequently because reminders can be set for any time, not just on the hour.
class CustomReminderJob < ReminderJob
  def perform
    ActsAsTenant.without_tenant do
      clean_old_deliveries
      scheduled_deliveries_by_community.each do |community, deliveries|
        with_cluster(community.cluster) do
          deliveries.each { |delivery| deliver_resiliently(delivery) }
        end
      end
    end
  end

  private

  # A delivery error for one recipient shouldn't abort the run. Otherwise the delivery isn't
  # destroyed and the recipients before the failure get a duplicate on the next run.
  def deliver_resiliently(delivery)
    delivery.deliver! do |send_one|
      with_mail_delivery_resilience(data: {reminder_delivery_id: delivery.id}) { send_one.call }
    end
  end

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
     shift: {assignments: :user, job: {period: :community}},
     meal: [:community, assignments: %i[user role]]]
  end
end
