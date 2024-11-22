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
            guidelines_ok: "1",
            name: Faker::Hipster.words(number: 2).join(" ").capitalize[0..23],
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
        end
      end

      private

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
