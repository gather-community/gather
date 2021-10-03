# frozen_string_literal: true

class PopulateAllDaySystemCalendars < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      # Ensure these classes are autoloaded in development or the colors aren't computed properly.
      Calendars::System::CommunityMealsCalendar.all
      Calendars::System::OtherCommunitiesMealsCalendar.all
      Calendars::System::YourMealsCalendar.all

      Community.all.find_each do |community|
        cluster = community.cluster
        ActsAsTenant.with_tenant(cluster) do
          work_rank = Calendars::Group.find_by(name: "Reservations", community: community)&.rank
          work_rank += 1 unless work_rank.nil?
          work_group = Calendars::Group.create!(name: "Work", rank: work_rank, community: community)
          Calendars::System::YourJobsCalendar.create!(name: "Your Jobs", color: next_color(community),
                                                      community: community, selected_by_default: true,
                                                      group: work_group)
          Calendars::System::BirthdaysCalendar.create!(name: "Birthdays", color: next_color(community),
                                                       community: community, selected_by_default: true)
          Calendars::System::JoinDatesCalendar.create!(name: "Join Dates", color: next_color(community),
                                                       community: community, selected_by_default: true)
        end
      end
    end
  end

  private

  def next_color(community)
    Calendars::Calendar.least_used_colors(community).first
  end
end
