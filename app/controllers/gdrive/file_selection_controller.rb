# frozen_string_literal: true

module GDrive
  class FileSelectionController < ApplicationController
    include GDriveable

    prepend_before_action :set_current_community_from_query_string
    skip_before_action :verify_authenticity_token, only: :mark
    before_action -> { nav_context(:wiki, :gdrive, :setup, :file_selection) }

    def index
      authorize(current_community, policy_class: FileSelectionPolicy)
      skip_policy_scope
      @config = Config.find_by(community: current_community)
      @auth_policy = AuthPolicy.new(current_user, current_community)
      if @config&.complete?
        credentials = fetch_credentials_from_store
        credentials.fetch_access_token!
        @access_token = credentials.access_token
      end
    end

    def mark
      authorize(current_community, policy_class: FileSelectionPolicy)
      puts "Item count: #{params[:docs].size}"
    end
  end
end
