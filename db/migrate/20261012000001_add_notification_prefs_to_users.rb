# frozen_string_literal: true

# Stores each user's notification preferences, as overrides of the defaults in People::NotificationCatalog.
class AddNotificationPrefsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_prefs, :jsonb, null: false, default: {}
    add_check_constraint :users, "jsonb_typeof(notification_prefs) = 'object'",
      name: "notification_prefs_object"
  end
end
