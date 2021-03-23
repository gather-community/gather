# frozen_string_literal: true

module Utils
  module Generators
    class CalendarGenerator < Generator
      attr_accessor :community, :calendar_data, :calendar_map, :photos

      def initialize(community:, photos:)
        self.community = community
        self.photos = photos
        self.calendar_map = {}
      end

      def generate_samples
        create_main_calendars
        create_reservation_calendars
        create_shared_guidelines_and_associate
        create_calendar_protocols_and_associate
      end

      def calendars
        calendar_map.values
      end

      def cleanup_on_error
        calendars&.each { |u| u.photo&.destroy }
      end

      private

      def create_main_calendars
        create(:calendar, name: "Social Events", abbrv: nil, community: community)
        create(:calendar, name: "Meetings", abbrv: nil, community: community)
      end

      def create_reservation_calendars
        reservations_group = create(:calendar_group, community: community, name: "Reservations")
        self.calendar_data = load_yaml("calendars/calendars.yml")
        calendar_data.each do |row|
          calendar = create(:calendar, row.except("id", :shared_guideline_ids).merge(
            community: community,
            group: reservations_group,
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
          calendar.photo.attach(io: calendar_photo(row["id"]), filename: "#{row['id']}.jpg") if photos
          row[:obj] = calendar
          calendar_map[row["id"]] = row[:obj]
        end
      end

      def create_shared_guidelines_and_associate
        load_yaml("calendars/shared_guidelines.yml").each do |row|
          sg = Calendars::SharedGuidelines.create!(row.except("id").merge(community: community))
          calendars_with_shared_guidelines_id(row["id"]).each do |calendar|
            calendar.shared_guidelines << sg
          end
        end
      end

      def create_calendar_protocols_and_associate
        load_yaml("calendars/protocols.yml").each do |row|
          protocol = create(:calendar_protocol, row.except("id").merge(community: community))
          protocol.calendars = calendars_with_protocol_id(row["id"])
        end
      end

      def calendar_photo(id)
        File.open(resource_path("photos/calendars/calendars/#{id}.jpg"))
      end

      def calendars_with_shared_guidelines_id(id)
        calendar_data.select { |r| r[:shared_guideline_ids].include?(id) }.map { |r| r[:obj] }
      end

      def calendars_with_protocol_id(id)
        @protocoling_data = load_yaml("calendars/protocolings.yml")
        calendar_ids = @protocoling_data.select { |p| p["protocol_id"] == id }.map { |p| p["calendar_id"] }
        calendar_data.select { |r| calendar_ids.include?(r["id"]) }.map { |r| r[:obj] }
      end
    end
  end
end
