# frozen_string_literal: true

module Calendars
  class MultiEventsController < ApplicationController
    before_action -> { nav_context(:calendars, :events) }

    def new
      @form = MultiEventForm.new(
        action: :new,
        current_user: current_user,
        params: {starts_at: params[:start], ends_at: params[:end], origin_page: params[:origin_page]}
      )
      authorize_form(:create?)
      prep_form_vars
    end

    def create
      @form = MultiEventForm.new(
        action: :create,
        current_user: current_user,
        params: params.require(:calendars_event)
      )
      authorize_form(:create?)
      if @form.save
        flash[:success] = "Events created successfully."
        redirect_after_save
      else
        prep_form_vars
        render(:new, status: :unprocessable_entity)
      end
    end

    def edit
      @form = MultiEventForm.new(
        action: :edit,
        current_user: current_user,
        id: params[:id],
        params: {guidelines_ok: "1", origin_page: params[:origin_page]}
      )
      authorize_form(:update?)
      prep_form_vars
    end

    def update
      @form = MultiEventForm.new(
        action: :update,
        current_user: current_user,
        id: params[:id],
        params: params.require(:calendars_event)
      )
      authorize_form(:update?)
      if @form.save
        flash[:success] = "Events updated successfully."
        redirect_after_save
      else
        prep_form_vars
        render(:edit, status: :unprocessable_entity)
      end
    end

    # AJAX: re-renders the _multi_form partial on calendar selection change.
    # Populates the form from params but does NOT save anything.
    def form
      @form = MultiEventForm.new(
        action: :form,
        current_user: current_user,
        params: params.require(:calendars_event)
      )
      authorize_form(@form.persisted? ? :update? : :create?)
      prep_form_vars
      render(partial: "multi_form")
    end

    protected

    def community_for_route
      current_user.community
    end

    private

    def authorize_form(action)
      sample = @form.event.persisted? ? @form.event : Event.new(calendar: first_writeable_calendar)
      authorize(sample, action)
    end

    def first_writeable_calendar
      @form.calendar_slots.first&.calendar || writeable_calendars.first
    end

    def writeable_calendars
      @writeable_calendars ||=
        CalendarPolicy::Scope.new(current_user, Calendar.in_community(current_community)).resolve_for_create
    end

    def prep_form_vars
      @event = @form.event
      @groups = Calendars::EventPolicy::GroupScope.new(current_user, Groups::Group)
        .resolve.in_community(current_community).order(:name)
      @writeable_calendars = writeable_calendars
    end

    def redirect_after_save
      redirect_to(calendars_events_path(date: @form.starts_at&.to_fs(:no_time)))
    end
  end
end
