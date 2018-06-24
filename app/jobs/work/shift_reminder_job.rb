# frozen_string_literal: true

module Work
  # Sends notifications of job shifts.
  class ShiftReminderJob < ReminderJob
    def perform
      ActsAsTenant.without_tenant do
        scheduled_deliveries_by_community.each do |community, deliveries|
          with_community(community) do
            deliveries.each do |delivery|
              delivery.assignments.each do |assign|
                WorkMailer.shift_reminder(assign, delivery.reminder).deliver_now
              end
              delivery.update!(delivered: true)
            end
          end
        end
      end
    end

    private

    def scheduled_deliveries_by_community
      ReminderDelivery
        .where("deliver_at <= ?", Time.zone.now)
        .where(delivered: false)
        .includes(shift: {job: {period: :community}})
        .group_by(&:community)
    end
  end
end
