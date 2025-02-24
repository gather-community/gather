# frozen_string_literal: true

module Utils
  module Generators
    class CalendarGenerator < Generator
      attr_accessor :community, :calendar_data, :calendar_map, :photos, :reservations_group

      def initialize(community:, photos:)
        self.community = community
        self.photos = photos
        self.calendar_map = {}
      end

      def generate_seed_data
        create_main_calendars
        create_system_calendars
        self.reservations_group = create(:calendar_group, community: community, name: "Reservations")
      end

      def generate_samples
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
        create(:calendar, name: "Social Events", color: next_color, abbrv: nil,
                          community: community, selected_by_default: true)
        create(:calendar, name: "Meetings", color: next_color, abbrv: nil,
                          community: community, selected_by_default: true)
      end

      def create_system_calendars
        group = create(:calendar_group, community: community, name: "Meals")
        create(:community_meals_calendar, name: "All Meals", community: community, group: group,
                                          color: next_color, selected_by_default: true)
        create(:your_meals_calendar, name: "Your Meals", community: community, group: group,
                                     color: next_color)
        group = create(:calendar_group, community: community, name: "Work")
        create(:your_jobs_calendar, name: "Your Jobs", community: community, group: group,
                                    color: next_color)
        create(:birthdays_calendar, name: "Birthdays", community: community, color: next_color)
        create(:join_dates_calendar, name: "Join Dates", community: community, color: next_color)
      end

      def create_reservation_calendars
        self.calendar_data = load_yaml("calendars/calendars.yml")
        calendar_data.each do |row|
          calendar = create(:calendar, row.except("id", :shared_guideline_ids).merge(
            community: community,
            color: next_color,
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
        calendar_data.select { |r| r[:shared_guideline_ids].include?(id) }.pluck(:obj)
      end

      def calendars_with_protocol_id(id)
        @protocoling_data = load_yaml("calendars/protocolings.yml")
        calendar_ids = @protocoling_data.select { |p| p["protocol_id"] == id }.map { |p| p["calendar_id"] }
        calendar_data.select { |r| calendar_ids.include?(r["id"]) }.pluck(:obj)
      end

      def next_color
        Calendars::Calendar.least_used_colors(community).first
      end
    end
  end
end
