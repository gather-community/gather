# frozen_string_literal: true

module Utils
  module Generators
    class EventGenerator < Generator
      attr_accessor :calendar_map, :community, :data

      EVENTS_EXPORTED_ON = Date.new(2017, 6, 14)

      def initialize(community:, calendar_map:)
        self.community = community
        self.calendar_map = calendar_map
      end

      def generate_samples
        self.data = load_yaml("calendars/events.yml")
        adults = User.adults.active.to_a

        data.each do |row|
          Calendars::Event.create!(row.except("id", "calendar_id").merge(
            starts_at: translate_time(row["starts_at"]),
            ends_at: translate_time(row["ends_at"]),
            creator: adults.sample,
            calendar: calendar_map[row["calendar_id"]],
            name: Faker::Hipster.words(number: 2).join(" ").capitalize[0..23],
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
        end

        create_recurring_event_with_overrides(adults)
      end

      private

      def create_recurring_event_with_overrides(adults)
        event = create_weekly_event(adults)
        occ_start = event.occurrences_between(2.weeks.from_now..12.weeks.from_now).first.first
        event_override = Calendars::EventOverride.create!(event: event, occurrence_start: occ_start,
          deleted: true)
        Calendars::EventletOverride.create!(event_override: event_override,
          eventlet: event.eventlets.first, deleted: true)
      end

      def create_weekly_event(adults)
        Calendars::Event.create!(
          name: "Weekly gathering",
          calendar: calendar_map.values.first,
          creator: adults.sample,
          starts_at: 1.week.from_now.beginning_of_week + 10.hours,
          ends_at: 1.week.from_now.beginning_of_week + 11.hours,
          recurrence_rule: IceCube::Rule.weekly.to_hash
        )
      end

      # Calculate offset to shift events so that latest one is 30 days from now
      def date_offset
        @date_offset ||= Date.today - EVENTS_EXPORTED_ON
      end

      def translate_time(datetime)
        datetime = datetime.in_time_zone("Eastern Time (US & Canada)")
        date = datetime.to_date + date_offset
        time = datetime.strftime("%H:%M")
        Time.zone.parse("#{date.to_fs} #{time}")
      end
    end
  end
end
