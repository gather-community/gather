# frozen_string_literal: true

module Calendars
  # Gen 1 and Gen 2 calendar exports
  class LegacyExportsController < ApplicationController
    include Exportable

    # Users are authenticated from the provided token for the personalized endpoint.
    prepend_before_action :authenticate_user_from_token!, only: :personalized

    # This is skipped to support legacy domains.
    skip_before_action :ensure_subdomain, only: :personalized

    # Community calendars are not user-specific. Authorization is handled by the policy class
    # based on the community calendar token.
    skip_before_action :authenticate_user!, only: :community

    def community
      export = Exports::Factory.build(type: params[:type], community: current_community)
      policy = ExportPolicy.new(nil, export, community_token: params[:calendar_token])
      authorize_with_explict_policy_object(export, :community?, policy_object: policy)
      send_calendar_data(export)
    rescue Exports::TypeError
      handle_calendar_error
    end

    def personalized
      export = Exports::Factory.build(type: params[:type], user: current_user)
      authorize(export, policy_class: ExportPolicy)
      send_calendar_data(export)
    rescue Exports::TypeError
      handle_calendar_error
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      current_user.community if params[:action] == "personalized"
    end

    def export_file_basename
      params[:type]
    end

    private

    def sample_export
      Exports::Export.new(user: current_user)
    end
  end
end
