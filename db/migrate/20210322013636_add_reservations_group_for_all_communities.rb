# frozen_string_literal: true

class AddReservationsGroupForAllCommunities < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      Community.find_each do |community|
        ActsAsTenant.with_tenant(community.cluster) do
          Calendars::Group.create(name: "Reservations",
                                  calendars: Calendars::Calendar.in_community(community).all,
                                  rank: 1,
                                  community: community)
        end
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      Calendars::Group.destroy_all
    end
  end
end
