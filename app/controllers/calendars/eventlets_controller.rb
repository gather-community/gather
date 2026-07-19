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

    # Drag-and-drop in the calendar grid. XHR only; the response body is consumed by the grid's
    # error modal, matching EventsController#update.
    def update
      @eventlet = Eventlet.find(params[:id])
      authorize(@eventlet)
      @form = EventletForm.new(eventlet: @eventlet, current_user: current_user,
        params: params.require(:calendars_eventlet))

      if @form.save
        head(:ok)
      else
        render(partial: "calendars/events/update_error_messages", locals: {errors: @form.errors},
          status: :unprocessable_entity)
      end
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "show", "update"
        Eventlet.find_by(id: params[:id]).try(:community)
      end
    end
  end
end
