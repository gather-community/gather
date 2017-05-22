class SetTimeZoneForExistingCommunities < ActiveRecord::Migration
  def up
    ActsAsTenant.without_tenant do
      Community.all.each do |c|
        c.settings.time_zone = "Eastern Time (US & Canada)"
        c.save!
      end
    end
  end
end
