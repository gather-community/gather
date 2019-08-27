# frozen_string_literal: true

module Utils
  module Generators
    class ReservationGenerator < Generator
      attr_accessor :resource_map, :community, :data

      RESERVATIONS_EXPORTED_ON = Date.new(2017, 6, 14)

      def initialize(community:, resource_map:)
        self.community = community
        self.resource_map = resource_map
      end

      def generate_samples
        self.data = load_yaml("reservation/reservations.yml")
        adults = User.adults.active.to_a

        data.each do |row|
          Reservations::Reservation.create!(row.except("id", "resource_id").merge(
            starts_at: translate_time(row["starts_at"]),
            ends_at: translate_time(row["ends_at"]),
            reserver: adults.sample,
            resource: resource_map[row["resource_id"]],
            guidelines_ok: "1",
            name: Faker::Hipster.words(2).join(" ").capitalize[0..23],
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
        end
      end

      private

      # Calculate offset to shift reservations so that latest one is 30 days from now
      def date_offset
        @date_offset ||= Date.today - RESERVATIONS_EXPORTED_ON
      end

      def translate_time(datetime)
        datetime = datetime.in_time_zone("Eastern Time (US & Canada)")
        date = datetime.to_date + date_offset
        time = datetime.strftime("%H:%M")
        Time.zone.parse("#{date} #{time}")
      end
    end
  end
end
