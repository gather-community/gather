# Models a single reservation rule, such as max_minutes_per_year = 200.
# Also stores a reference to the Reservation::Protocol giving rise to the rule.
module Reservation
  class Rule
    attr_accessor :name, :value, :protocol

    NAMES = %i(fixed_start_time fixed_end_time max_lead_days
      max_length_minutes max_minutes_per_year requires_sponsor)

    def initialize(name: nil, value: nil, protocol: nil)
      self.name = name
      self.value = value
      self.protocol = protocol
    end

    def check(reservation)
      case name
      when "fixed_start_time"
        value.strftime("%T") == reservation.starts_at.strftime("%T") ||
          [:starts_at, "it must start at #{value.to_s(:regular_time)}"]

      when "fixed_end_time"
        value.strftime("%T") == reservation.ends_at.strftime("%T") ||
          [:ends_at, "it must end at #{value.to_s(:regular_time)}"]

      when "max_lead_days"
        reservation.starts_at.to_date - Date.today <= value ||
          [:starts_at, "it can be at most #{value} days in the future"]

      when "max_length_minutes"
        reservation.ends_at - reservation.starts_at <= value * 60 ||
          [:ends_at, "it can be at most #{Utils::TimeUtils::humanize_interval(value * 60)} in length"]

      when "max_minutes_per_year"
        booked = booked_time_for_year(reservation, :seconds)
        if booked >= value * 60
          [:base, "you have already reached your yearly limit of "\
            "#{Utils::TimeUtils::humanize_interval(value * 60)} for this resource"]
        elsif booked + reservation.seconds > value * 60
          [:base, "you can book at most #{Utils::TimeUtils::humanize_interval(value * 60)} per year "\
            "and you have already booked #{Utils::TimeUtils::humanize_interval(booked)}"]
        else
          true
        end

      when "max_days_per_year"
        booked = booked_time_for_year(reservation, :days)
        if booked >= value
          [:base, "you have already reached your yearly limit of #{value} days for this resource"]
        elsif booked + reservation.days > value
          [:base, "you can book at most #{value} days per year and "\
            "you have already booked #{booked} days"]
        else
          true
        end

      when "requires_sponsor"
        reservation.user_community == protocol.community ||
          reservation.sponsor_community == protocol.community ||
          [:sponsor_id, "you must have a sponsor"]

      else
        raise "Unknown rule name"
      end
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
