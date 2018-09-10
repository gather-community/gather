# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for limiting number of total minutes booked per year.
    class MaxMinutesPerYearRule < Rule
      def check(reservation)
        booked = booked_time_for_year(reservation, :seconds)
        if booked >= value * 60
          [:base, "You have already reached your yearly limit of "\
            "#{Utils::TimeUtils.humanize_interval(value * 60)} for this resource"]
        elsif booked + reservation.seconds > value * 60
          [:base, "You can book at most #{Utils::TimeUtils.humanize_interval(value * 60)} per year "\
            "and you have already booked #{Utils::TimeUtils.humanize_interval(booked)}"]
        else
          true
        end
      end
    end
  end
end
