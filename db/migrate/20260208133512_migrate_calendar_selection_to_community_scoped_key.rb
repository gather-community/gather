# frozen_string_literal: true

class MigrateCalendarSelectionToCommunityScopedKey < ActiveRecord::Migration[7.0]
  def up
    ActsAsTenant.without_tenant do
      User.joins(:household)
        .where("users.settings ? 'calendar_selection'")
        .where("users.settings->'calendar_selection' IS NOT NULL")
        .where("users.settings->'calendar_selection' != ?", "null")
        .find_each do |user|
          selection = user.settings["calendar_selection"]
          next if selection.blank?

          community_id = user.household.community_id
          new_key = "calendar_selection_#{community_id}"
          next if user.settings[new_key].present?

          user.update_column(:settings, user.settings.merge(new_key => selection))
        end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      User.find_each do |user|
        keys_to_remove = user.settings.keys.select { |k| k.start_with?("calendar_selection_") }
        next if keys_to_remove.empty?

        user.update_column(:settings, user.settings.except(*keys_to_remove))
      end
    end
  end
end
