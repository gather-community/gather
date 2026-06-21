# frozen_string_literal: true

module Calendars
  # Shows a single occurrence of a calendar event. For recurring series, the specific occurrence is
  # identified by the `occurrence` query param (a unix timestamp of the original occurrence start).
  class EventletsController < ApplicationController
    decorates_assigned :occurrence

    before_action -> { nav_context(:calendars, :events) }

    def show
      @eventlet = Eventlet.find(params[:id])
      authorize(@eventlet)
      @occurrence = OccurrenceResolver.new(@eventlet, params[:occurrence]).resolve
      raise ActiveRecord::RecordNotFound unless @occurrence
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "show"
        Eventlet.find_by(id: params[:id]).try(:community)
      end
    end
  end
end
