# frozen_string_literal: true

module Calendars
  class CalendarsController < ApplicationController
    include Destructible

    decorates_assigned :calendar
    helper_method :sample_calendar

    before_action -> { nav_context(:calendars, :calendars) }

    def index
      authorize(sample_node)
      prep_calendar_table
    end

    def new
      @calendar = sample_calendar
      authorize(@calendar)
      prep_form_vars
    end

    def edit
      @calendar = Calendar.find(params[:id])
      authorize(@calendar)
      prep_form_vars
    end

    def create
      @calendar = sample_calendar
      @calendar.assign_attributes(calendar_params)
      authorize(@calendar)
      if @calendar.save
        flash[:success] = "Calendar created successfully."
        redirect_to(calendars_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @calendar = Calendar.find(params[:id])
      authorize(@calendar)
      if @calendar.update(calendar_params)
        flash[:success] = "Calendar updated successfully."
        redirect_to(calendars_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    # Moves calendars or groups up or down.
    def move
      @node = Node.find(params[:id])
      authorize(@node)
      delta = case params[:dir]
              when "up" then -1
              when "down" then 1
              else 0
              end
      @node.update!(rank: @node.rank + delta)
      prep_calendar_table
      render(partial: "table")
    end

    protected

    def klass
      Calendar
    end

    private

    def prep_calendar_table
      @calendar_nodes = policy_scope(Node).with_event_counts.in_community(current_community).arrange
    end

    def sample_node
      @sample_node ||= Node.new(community: current_community)
    end

    def sample_calendar
      @sample_calendar ||= Calendar.new(community: current_community,
                                        color: Calendar.next_color(current_community))
    end

    def prep_form_vars
      @max_photo_size = Calendar.validators_on(:photo).detect { |v| v.is_a?(FileSizeValidator) }.options[:max]
      @group_options = policy_scope(Group).in_community(current_community).by_rank
    end

    # Pundit built-in helper doesn't work due to namespacing
    def calendar_params
      params.require(:calendars_calendar).permit(policy(@calendar).permitted_attributes)
    end
  end
end
