# Models a single reservation rule, such as max_minutes_per_year = 200.
# Also stores a reference to the Reservation::Protocol giving rise to the rule.
module Reservation
  class Rule
    attr_accessor :name, :value, :protocol

    delegate :community, to: :protocol, prefix: true

    NAMES = %i(fixed_start_time fixed_end_time max_lead_days
      max_length_minutes max_minutes_per_year
      other_communities requires_kind)

    def initialize(name: nil, value: nil, protocol: nil)
      self.name = name
      self.value = value
      self.protocol = protocol
    end

    # Returns true if reservation passes the check (conforms to the rule).
    # Returns a 2-element array for AR errors.add if not.
    def check(reservation)
      case name
      when :fixed_start_time
        value.strftime("%T") == reservation.starts_at.strftime("%T") ||
          [:starts_at, "Must be #{value.to_s(:regular_time)}"]

      when :fixed_end_time
        value.strftime("%T") == reservation.ends_at.strftime("%T") ||
          [:ends_at, "Must be #{value.to_s(:regular_time)}"]

      when :max_lead_days
        reservation.starts_at.to_date - Time.zone.today <= value ||
          [:starts_at, "Can be at most #{value} days in the future"]

      when :max_length_minutes
        reservation.ends_at - reservation.starts_at <= value * 60 ||
          [:ends_at, "Can be at most #{Utils::TimeUtils::humanize_interval(value * 60)} after start time"]

      when :max_minutes_per_year
        booked = booked_time_for_year(reservation, :seconds)
        if booked >= value * 60
          [:base, "You have already reached your yearly limit of "\
            "#{Utils::TimeUtils::humanize_interval(value * 60)} for this resource"]
        elsif booked + reservation.seconds > value * 60
          [:base, "You can book at most #{Utils::TimeUtils::humanize_interval(value * 60)} per year "\
            "and you have already booked #{Utils::TimeUtils::humanize_interval(booked)}"]
        else
          true
        end

      when :max_days_per_year
        booked = booked_time_for_year(reservation, :days)
        if booked >= value
          [:base, "You have already reached your yearly limit of #{value} days for this resource"]
        elsif booked + reservation.days > value
          [:base, "You can book at most #{value} days per year and "\
            "you have already booked #{booked} days"]
        else
          true
        end

      when :other_communities
        case value
        when "forbidden", "read_only"
          reservation.reserver_community == protocol.community ||
            [:base, "Residents from other communities may not make reservations"]
        when "sponsor"
          reservation.reserver_community == protocol.community ||
            reservation.sponsor_community == protocol.community ||
            [:sponsor_id, "You must have a sponsor from #{protocol.community_name}"]
        else
          raise "Unknown value for other_communities rule"
        end

      when :requires_kind
        reservation.kind.present? || [:kind, "can't be blank"]

      when :pre_warning
        true

      else
        raise "Unknown rule name"
      end
    end

    def to_s
      "#{name}: #{value}"
    end

    private

    def booked_time_for_year(reservation, unit)
      year = reservation.starts_at.year
      Reservation.booked_time_for(
        resources: protocol.resources,
        household: reservation.household,
        period: Time.zone.local(year)...Time.zone.local(year + 1),
        unit: unit
      )
    end
  end
end
