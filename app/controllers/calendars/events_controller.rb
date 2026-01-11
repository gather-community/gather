# frozen_string_literal: true

module Calendars
  # Main events controller.
  class EventsController < ApplicationController
    include Lensable

    BASE_LENSES = %i[calendars/view_type calendars/date calendars/early_morning].freeze

    decorates_assigned :event, :calendar, :calendars, :meal

    before_action -> { nav_context(:calendars, :events) }

    def index
      set_no_cache # Cache means lens would not be respected on back button click.
      return update_lenses_and_quit(*BASE_LENSES) if params[:update_lenses]
      return render_json_event_list if request.xhr?

      calendar_scope = policy_scope(Node).in_community(current_community).active
      @calendars = calendar_scope.arrange(decorator: CalendarDecorator)
      if params[:calendar_id]
        @calendar = Calendar.find(params[:calendar_id])
        prep_single_calendar_index
      else
        prep_combined_index(calendar_scope)
      end
    end

    def show
      @event = Event.find(params[:id])
      authorize(@event)
      @calendar = @event.calendar
      @meal = @event.meal
    end

    def new
      if params[:calendar_id]
        @form = EventForm.new(
          action: :new,
          current_user: current_user,
          params: {
            creator_id: current_user.id,
            calendar_id: params[:calendar_id],
            starts_at: params[:start],
            ends_at: params[:end],
            origin_page: params[:origin_page]
          }
        )
        @event = @form.event
        authorize(@event)

        prep_form_vars
      elsif writeable_calendars.any?
        render_choose_calendar_page
      else
        render_no_calendars
      end
    end

    def edit
      @form = EventForm.new(
        action: :edit,
        current_user: current_user,
        id: params[:id],
        params: {
          origin_page: params[:origin_page],
          guidelines_ok: "1"
        }
      )
      @event = @form.event
      authorize(@event)

      prep_form_vars
    end

    def create
      # If the calendar_id is blank, we can't even do proper authorization, so we short circuit.
      if params[:calendars_event][:calendar_id].blank?
        skip_authorization
        render_error_page(:unprocessable_entity)
        return
      end

      @form = EventForm.new(
        action: :create,
        current_user: current_user,
        params: params.require(:calendars_event)
      )
      @event = @form.event

      authorize(@event)
      if @form.save
        flash[:success] = "Event created successfully."
        redirect_to_event_in_context(@form)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      event_params = params.require(:calendars_event)

      @form = EventForm.new(
        action: :update,
        current_user: current_user,
        id: params[:id],
        params: event_params
      )
      @event = @form.event

      authorize(@event)

      if @form.save
        if request.xhr?
          head(:ok)
        else
          flash[:success] = "Event updated successfully."
          redirect_to_event_in_context(@form)
        end
      else
        if request.xhr?
          render(partial: "update_error_messages", status: :unprocessable_entity)
        else
          prep_form_vars
          render(:edit)
        end
      end
    end

    def destroy
      @form = EventForm.new(
        action: :destroy,
        current_user: current_user,
        id: params[:id],
        params: {
          origin_page: params[:origin_page]
        }
      )
      @event = @form.event
      authorize(@event)
      @event.destroy
      flash[:success] = "Event deleted successfully."
      redirect_to_event_in_context(@form)
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

    def prep_single_calendar_index
      # We use an unsaved sample event to authorize against.
      # We set kind to nil because we can't know the kind in advance. This object is also used
      # to fetch a RuleSet for use in showing other_communities warnings and fixed start/end times.
      # As such, only warnings and fixed time rules that don't specify a particular kind will be observed.
      # Kind-specific rules will be enforced through validation.
      sample_event = Event.new(calendar: @calendar, creator: current_user, kind: nil)
      authorize(sample_event)
      prepare_lenses(*BASE_LENSES)
      @can_create_event = policy(sample_event).create?

      @rule_set = sample_event.rule_set
      if @rule_set.access_level(current_user.community) == "read_only"
        flash.now[:notice] = "Only #{@calendar.community_name} residents may reserve this calendar."
      end
      @rule_set_serializer = build_attribute_serializer(@rule_set, creator_community: Community.first,
        serializer: RuleSetSerializer)
      @other_communities = Community.where("id != ?", @calendar.community_id)

      @new_event_path = new_calendar_event_path(@calendar)
      @permalink = calendar_events_path(@calendar)
      # Feed path doesn't need calendar_id because the JS calendar view is responsible for inserting
      # whichever calendar ids the user selects, or the single ID in the case of single view.
      @feed_path = calendars_events_path
    end

    def prep_combined_index(calendar_scope)
      authorize(Event)
      prepare_lenses(*[community: {clearable: false}].concat(BASE_LENSES))
      @rule_set_serializer = {}
      @can_create_event = writeable_calendars.any?
      setting = current_user.settings["calendar_selection"]
      @calendar_selection = InitialSelection.new(stored: setting, calendar_scope: calendar_scope).selection

      @new_event_path = new_calendars_event_path(origin_page: "combined")
      # Permalink doesn't need origin page
      @permalink = calendars_events_path
      # Feed path doesn't need calendar_id because the JS calendar view is responsible for inserting
      # whichever calendar ids the user selects, or the single ID in the case of single view.
      @feed_path = calendars_events_path(origin_page: "combined")
    end

    def writeable_calendars
      @writeable_calendars ||=
        CalendarPolicy::Scope.new(current_user, Calendar.in_community(current_community)).resolve_for_create
    end

    def render_json_event_list
      skip_policy_scope # This is checked in EventFinder and system calendars
      range = Time.zone.parse(params[:start])..Time.zone.parse(params[:end])
      calendars = Calendar.where(id: params[:calendar_ids]&.split(" "))
      events = EventFinder.new(range: range, calendars: calendars, user: current_user).events
      # The adapter option removes the root.
      render(json: events, adapter: :attributes, origin_page: params[:origin_page])
    end

    def prep_form_vars
      @calendar = @event.calendar
      @rule_set = @event.rule_set
      @kinds = @calendar.kinds # May be nil
      @groups = Calendars::EventPolicy::GroupScope.new(current_user, Groups::Group)
        .resolve
        .in_community(current_community)
        .order(:name)
    end

    def render_choose_calendar_page
      # This sample event is just for authorizing the new action on CalendarEvent.
      sample_event = Event.new(calendar: writeable_calendars.first, creator: current_user)
      authorize(sample_event)

      @calendars = writeable_calendars
      @url_params = params.permit(:start, :end, :origin_page)
    end

    def render_no_calendars
      sample_calendar = Calendar.new(community: current_community)

      # This sample event is just for authorizing the new action on CalendarEvent.
      sample_event = Event.new(calendar: sample_calendar, creator: current_user)
      authorize(sample_event)

      @can_create_calendar = policy(sample_calendar).create?
      @calendars = []
    end

    def redirect_to_event_in_context(event_form)
      params = {date: event_form.starts_at&.to_fs(:no_time)}
      if event_form.origin_page == "combined"
        redirect_to(calendars_events_path(params))
      else
        redirect_to(calendar_events_path(event_form.calendar, params))
      end
    end
  end
end
