# frozen_string_literal: true

class PopulateGeneralCalendars < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      # Ensure these classes are autoloaded in development or the colors aren't computed properly.
      Calendars::System::CommunityMealsCalendar.all
      Calendars::System::OtherCommunitiesMealsCalendar.all
      Calendars::System::YourMealsCalendar.all

      Community.all.find_each do |community|
        cluster = community.cluster
        ActsAsTenant.with_tenant(cluster) do
          Calendars::Calendar.create!(name: "Social Events", color: next_color(community),
                                      community: community, selected_by_default: true, rank: 1)
          Calendars::Calendar.create!(name: "Meetings", color: next_color(community), community: community,
                                      selected_by_default: true, rank: 2)
        end
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      Calendars::Calendar.where(name: ["Social Events", "Meetings"], group_id: nil).delete_all
    end
  end

  private

  def next_color(community)
    Calendars::Calendar.least_used_colors(community).first
  end
end
