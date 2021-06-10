# frozen_string_literal: true

module Calendars
  class ProtocolsController < ApplicationController
    include Destructible

    decorates_assigned :protocol, :protocols
    helper_method :sample_protocol

    before_action -> { nav_context(:calendars, :protocols) }

    def index
      authorize(sample_protocol)
      @protocols = policy_scope(Protocol).in_community(current_community).includes(:calendars).by_name
      check_if_kinds_present
    end

    def new
      @protocol = sample_protocol
      authorize(@protocol)
      prep_form_vars
    end

    def edit
      @protocol = Protocol.find(params[:id])
      authorize(@protocol)
      prep_form_vars
    end

    def create
      @protocol = sample_protocol
      @protocol.assign_attributes(protocol_params)
      authorize(@protocol)
      if @protocol.save
        flash[:success] = "Protocol created successfully."
        redirect_to(calendars_protocols_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @protocol = Protocol.find(params[:id])
      authorize(@protocol)
      if @protocol.update(protocol_params)
        flash[:success] = "Protocol updated successfully."
        redirect_to(calendars_protocols_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    protected

    def klass
      Protocol
    end

    private

    def sample_protocol
      @sample_protocol ||= Protocol.new(community: current_community)
    end

    def prep_form_vars
      @calendar_options = policy_scope(Calendar).in_community(current_community)
        .non_system.active.by_name.decorate
      @kind_options = (current_community.settings.calendars.kinds || "").split(/\s*,\s*/)
    end

    def check_if_kinds_present
      @kinds_present = current_community.settings.calendars.kinds.present?
    end

    # Pundit built-in helper doesn't work due to namespacing
    def protocol_params
      params.require(:calendars_protocol).permit(policy(@protocol).permitted_attributes)
    end
  end
end
