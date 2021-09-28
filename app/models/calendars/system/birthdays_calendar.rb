# frozen_string_literal: true

module Calendars
  module System
    # Returns people's birthdays
    class BirthdaysCalendar < SystemCalendar
      def events_between(range, user: user)
        lower = range.first
        upper = range.last
        users = User.in_community(community).active.where.not(birthdate: nil)
        events = (lower.year..upper.year).flat_map do |year|
          users.map do |user|
            month = user.birthdate.month
            day = user.birthdate.day
            feb29 = !Date.leap?(year) && month == 2 && day == 29
            candidate = feb29 ? Date.new(year, 2, 28) : Date.new(year, month, day)
            range.include?(candidate) ? event_for(candidate, user) : nil
          end
        end
        events.compact.sort_by(&:starts_at)
      end

      def all_day_allowed?
        true
      end

      private

      def event_for(date, user)
        age = date.year - user.birthdate.year
        title = +"🎂 #{user.name}"
        title << " (#{age})" if age <= 18
        events.build(
          name: title,
          starts_at: date.in_time_zone,
          ends_at: date.in_time_zone + 1.day - 1.second,
          linkable: user,
          all_day: true
        )
      end
    end
  end
end
