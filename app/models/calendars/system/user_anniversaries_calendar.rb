# frozen_string_literal: true

module Calendars
  module System
    # Returns people's birthdays
    class UserAnniversariesCalendar < SystemCalendar
      def all_day_allowed?
        true
      end

      def events_between(range, actor:)
        lower = range.first
        upper = range.last
        users = User.in_community(community).active.where.not(attrib => nil)

        # Try the anniversaries for each year
        events = (lower.year..upper.year).flat_map do |year|
          users.map do |user|
            month = user[attrib].month
            day = user[attrib].day

            # If the anniversary is on feb 29 and it's not a leap year, use feb 28
            day = 28 if !Date.leap?(year) && month == 2 && day == 29

            candidate_day_start = Time.zone.local(year, month, day, 0, 0)
            candidate_day_end = Time.zone.local(year, month, day, 11, 59)

            # We match if the range overlaps _any part of_ the candidate day
            range.first <= candidate_day_end && range.last >= candidate_day_start ? event_for(Date.new(year, month, day), user) : nil
          end
        end
        events.compact.sort_by(&:starts_at)
      end

      private

      def event_for(date, user)
        age = date.year - user[attrib].year
        title = +"#{emoji} #{user.name}"
        title << " (#{age})" if age <= 18
        events.build(
          name: title,
          starts_at: date.in_time_zone,
          ends_at: date.in_time_zone + 1.day - 1.second,
          linkable: user,
          uid: "#{slug}_#{user.id}",
          all_day: true
        )
      end
    end
  end
end
