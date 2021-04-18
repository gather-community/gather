# frozen_string_literal: true

module Calendars
  # Main events controller.
  class EventsController < ApplicationController
    include Lensable

    decorates_assigned :event, :calendar, :calendars, :meal

    before_action -> { nav_context(:calendars, :events) }

    def index
      @calendar = Calendar.find(params[:calendar_id]) if params[:calendar_id]
      return render_json_event_list if request.xhr?

      if @calendar
        # We use an unsaved sample event to authorize against.
        # We set kind to nil because we can't know the kind in advance. This object is also used
        # to fetch a RuleSet for use in showing other_communities warnings and fixed start/end times.
        # As such, only warnings and fixed time rules that don't specify a particular kind will be observed.
        # Kind-specific rules will be enforced through validation.
        @sample_event = Event.new(calendar: @calendar, creator: current_user, kind: nil)
        authorize(@sample_event)

        @rule_set = @sample_event.rule_set
        if @rule_set.access_level(current_user.community) == "read_only"
          flash.now[:notice] = "Only #{@calendar.community_name} residents may reserve this calendar."
        end
        @rule_set = RuleSetSerializer.new(@rule_set, creator_community: current_community)
        @other_calendars = policy_scope(Node).in_community(@calendar.community)
          .where("id != ?", @calendar.id).arrange
        @other_communities = Community.where("id != ?", @calendar.community_id)
      else
        authorize(Event)
        prepare_lenses(community: {clearable: false})
        @calendars = policy_scope(Node).in_community(current_community).arrange
        @rule_set = {}
      end
      @url_params = @calendar ? {calendar_id: @calendar.id} : {}
    end

    def show
      @event = Event.find(params[:id])
      authorize(@event)
      @calendar = @event.calendar
      @meal = @event.meal
    end

    def new
      @calendar = Calendar.find_by(id: params[:calendar_id])
      raise "Calendar not found" unless @calendar

      @event = Event.new_with_defaults(
        calendar: @calendar,
        creator: current_user,
        starts_at: params[:start],
        ends_at: params[:end]
      )
      authorize(@event)
      prep_form_vars
    end

    def edit
      @event = Event.find(params[:id])
      authorize(@event)
      @event.guidelines_ok = "1"
      prep_form_vars
    end

    def create
      @event = Event.new(creator: current_user)
      assign_calendar
      @event.assign_attributes(event_params)
      authorize(@event)
      if @event.save
        flash[:success] = "Event created successfully."
        redirect_to_event_in_context(@event)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @event = Event.find(params[:id])
      authorize(@event)
      return handle_xhr_update if request.xhr?
      if @event.update(event_params)
        flash[:success] = "Event updated successfully."
        redirect_to_event_in_context(@event)
      else
        prep_form_vars
        render(:edit)
      end
    end

    def destroy
      @event = Event.find(params[:id])
      authorize(@event)
      @event.destroy
      flash[:success] = "Event deleted successfully."
      redirect_to(calendars_events_path(calendar_id: @event.calendar_id))
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "show"
        Event.find_by(id: params[:id]).try(:community)
      when "index"
        current_user.community
      end
    end

    private

    def render_json_event_list
      @events = policy_scope(Event).where("starts_at < ? AND ends_at > ?",
                                          Time.zone.parse(params[:end]), Time.zone.parse(params[:start]))
      calendar_ids = @calendar ? [@calendar.id] : Calendar.in_community(current_community).pluck(:id)
      @events = @events.where(calendar_id: calendar_ids)
      render(json: @events, adapter: :attributes) # The adapter option removes the root.
    end

    def prep_form_vars
      @calendar ||= @event.calendar
      @kinds = @calendar.kinds # May be nil
    end

    def handle_xhr_update
      if @event.update(event_params.merge(guidelines_ok: "1"))
        head(:ok)
      else
        render(partial: "update_error_messages", status: :unprocessable_entity)
      end
    end

    # We need to set the calendar separately from the other parameters because
    # the calendar is what determines the community, and that determines what attributes
    # are permitted to be set. So we don't allow calendar_id itself through permitted_attributes.
    def assign_calendar
      @event.calendar = Calendar.find(params[:calendars_event][:calendar_id])
    end

    # Pundit built-in helper doesn't work due to namespacing
    def event_params
      permitted = params.require(:calendars_event).permit(policy(@event).permitted_attributes)
      permitted[:privileged_changer] = true if policy(@event).privileged_change?
      permitted
    end

    def redirect_to_event_in_context(event)
      redirect_to(calendars_events_path(calendar_id: event.calendar_id,
                                    date: event.starts_at&.to_s(:no_time)))
    end
  end
end
