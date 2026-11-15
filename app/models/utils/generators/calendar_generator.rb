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
        self.reservations_group = create(:calendar_group, community: community, name: starter(:reservations))
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
        %i[social_events meetings].each do |key|
          create(:calendar, name: I18n.t("starter_content.calendars.#{key}"), color: next_color, abbrv: nil,
            community: community, selected_by_default: true)
        end
      end

      def create_system_calendars
        group = create(:calendar_group, community: community, name: starter(:meals))
        create(:community_meals_calendar, name: I18n.t("calendars.all_meals"), community: community,
          group: group, color: next_color, selected_by_default: true)
        create(:my_meals_calendar, name: I18n.t("calendars.my_meals"), community: community, group: group,
          color: next_color)
        group = create(:calendar_group, community: community, name: starter(:work))
        create(:my_jobs_calendar, name: I18n.t("calendars.my_jobs"), community: community, group: group,
          color: next_color)
        create(:birthdays_calendar, name: I18n.t("starter_content.calendars.birthdays"), community: community,
          color: next_color)
        create(:join_dates_calendar, name: I18n.t("starter_content.calendars.join_dates"),
          community: community, color: next_color)
      end

      # The name of one of the starter calendar groups.
      def starter(group_key)
        I18n.t("starter_content.calendar_groups.#{group_key}")
      end

      def create_reservation_calendars
        self.calendar_data = load_yaml("calendars/calendars.yml")
        calendar_data.each do |row|
          calendar = create(:calendar, row.except("id", "key", :shared_guideline_ids).merge(
            **sample_text(:calendars, row["key"], :name, :abbrv, :guidelines),
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
          sg = Calendars::SharedGuidelines.create!(community: community,
            **sample_text(:shared_guidelines, row["key"], :name, :body))
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

      def next_color
        Calendars::Calendar.least_used_colors(community).first
      end
    end
  end
end
