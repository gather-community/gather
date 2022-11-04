# frozen_string_literal: true

module GDrive
  class FileSelectionController < ApplicationController
    include GDriveable

    prepend_before_action :set_current_community_from_query_string
    before_action -> { nav_context(:wiki, :gdrive, :setup, :file_selection) }

    def index
      authorize(:index, policy_class: AuthPolicy)
      skip_policy_scope
      @config = GDrive::Config.find_by(community: current_community)
      @auth_policy = GDrive::AuthPolicy.new(current_user, current_community)
      if @config&.complete?
        credentials = fetch_credentials_from_store
        credentials.fetch_access_token!
        @access_token = credentials.access_token
      end
    end
  end
end
