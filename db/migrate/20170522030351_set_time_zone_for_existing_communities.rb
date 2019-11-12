# frozen_string_literal: true

class SetTimeZoneForExistingCommunities < ActiveRecord::Migration[4.2]
  def up
    ActsAsTenant.without_tenant do
      Community.all.each do |c|
        c.settings.time_zone = "Eastern Time (US & Canada)"
        c.save!
      end
    end
  end
end
