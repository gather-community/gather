# frozen_string_literal: true

module Reservations
  class ProtocolsController < ApplicationController
    include Destructible

    decorates_assigned :protocol, :protocols
    helper_method :sample_protocol

    before_action -> { nav_context(:reservations, :protocols) }

    def index
      authorize sample_protocol
      @protocols = policy_scope(Protocol).in_community(current_community).includes(:resources).by_name
      @kinds_present = current_community.settings.reservations.kinds.present?
    end

    def new
      @protocol = sample_protocol
      authorize @protocol
    end

    def edit
      @protocol = Protocol.find(params[:id])
      authorize @protocol
    end

    def create
      @protocol = sample_protocol
      @protocol.assign_attributes(protocol_params)
      authorize @protocol
      if @protocol.save
        flash[:success] = "Protocol created successfully."
        redirect_to reservations_protocols_path
      else
        set_validation_error_notice(@protocol)
        render :new
      end
    end

    def update
      @protocol = Protocol.find(params[:id])
      authorize @protocol
      if @protocol.update(protocol_params)
        flash[:success] = "Protocol updated successfully."
        redirect_to reservations_protocols_path
      else
        set_validation_error_notice(@protocol)
        render :edit
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

    # Pundit built-in helper doesn't work due to namespacing
    def protocol_params
      params.require(:reservations_protocol).permit(policy(@protocol).permitted_attributes)
    end
  end
end
