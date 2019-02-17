# frozen_string_literal: true

class CreateDeliveriesForExistingReminders < ActiveRecord::Migration[5.1]
  def up
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        Work::JobReminder.all.each(&:create_or_update_deliveries)
      end
    end
    execute("UPDATE work_reminder_deliveries SET delivered ='t' WHERE deliver_at < NOW()")
  end
end
