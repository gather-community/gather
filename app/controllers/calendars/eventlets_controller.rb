# frozen_string_literal: true

module Calendars
  # Shows a single occurrence of a calendar event. For recurring series, the specific occurrence is
  # identified by the `occurrence` query param (a unix timestamp of the original occurrence start).
  class EventletsController < ApplicationController
    include EventContextRedirectable

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

    # Deletes the event, one occurrence of it, or the rest of its series, on this calendar or all of
    # them, per the scope choices made in the show page's delete modal.
    def destroy
      @eventlet = Eventlet.find(params[:id])
      @form = EventletDeletionForm.new(eventlet: @eventlet, current_user: current_user,
        params: params.require(:calendars_eventlet))

      if @form.invalid?
        skip_authorization # Nothing is written; the errors are shown to the user.
        flash[:error] = @form.errors.full_messages.to_sentence
      else
        # Matches show, which 404s for an occurrence that doesn't exist or was already deleted.
        raise ActiveRecord::RecordNotFound if @form.target_missing?
        @form.authorization_targets.each { |record| authorize(record, :destroy?) }
        @form.save
        flash[:success] = I18n.t("calendars.eventlet_deletion.success.#{@form.result_key}",
          calendar: @eventlet.calendar.name)
      end
      redirect_to_event_in_context(starts_at: @form.starts_at, calendar: @eventlet.calendar,
        origin_page: params[:origin_page])
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "show", "update", "destroy"
        Eventlet.find_by(id: params[:id]).try(:community)
      end
    end
  end
end
