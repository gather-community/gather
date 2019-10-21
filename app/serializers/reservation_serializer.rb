# frozen_string_literal: true

# For calendars.
class ReservationSerializer < ApplicationSerializer
  attributes :id, :url, :title, :start, :end, :editable, :className

  def url
    reservation_path(object)
  end

  def title
    object.name
  end

  def start
    # We don't include timezone in the format because the calendar doesn't have timezone
    # set either so we want everything to be ambiguously zoned and let the server
    # assume all incoming events are in the community's zone. The only reason we'd need
    # zone is if we someday wanted to mix times from several zones on the calendar but
    # we don't and can't foresee needing to.
    object.starts_at.to_s(:iso8601)
  end

  # end is a reserved word
  define_method("end") do
    object.ends_at.to_s(:iso8601)
  end

  def editable
    # scope == current_user
    Reservations::ReservationPolicy.new(scope, object).edit?
  end

  def className
    if object.meal
      "has-meal"
    elsif object.reserver == scope
      "own-reservation"
    else
      ""
    end
  end
end
