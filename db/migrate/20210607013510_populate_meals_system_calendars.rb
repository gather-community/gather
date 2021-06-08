# frozen_string_literal: true

class PopulateMealsSystemCalendars < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      Community.all.find_each do |community|
        cluster = community.cluster
        ActsAsTenant.with_tenant(cluster) do
          group = Calendars::Group.create!(name: "Meals", rank: 1, community: community)
          multi = cluster.multi_community?

          name = multi ? "#{community.abbrv} Meals" : "All Meals"
          color = Calendars::Calendar.least_used_colors(community).first
          Calendars::System::CommunityMealsCalendar.create!(name: name, color: color, community: community,
                                                            group: group, selected_by_default: true)

          if multi
            name = Community.where.not(id: community.id).map(&:abbrv).join("/") << " Meals"
            color = Calendars::Calendar.least_used_colors(community).first
            Calendars::System::OtherCommunitiesMealsCalendar.create!(name: name, color: color,
                                                                     community: community, group: group,
                                                                     selected_by_default: true)
          end

          name = "Your Meals"
          color = Calendars::Calendar.least_used_colors(community).first
          Calendars::System::YourMealsCalendar.create!(name: name, color: color, community: community,
                                                       group: group)
        end
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      Calendars::System::CommunityMealsCalendar.delete_all
      Calendars::System::OtherCommunitiesMealsCalendar.delete_all
      Calendars::System::YourMealsCalendar.delete_all
      Calendars::Group.where(name: "Meals").delete_all
    end
  end
end
