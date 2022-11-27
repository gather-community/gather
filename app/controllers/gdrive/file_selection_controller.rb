# frozen_string_literal: true

module GDrive
  class FileSelectionController < ApplicationController
    prepend_before_action :set_current_community_from_query_string
    skip_before_action :verify_authenticity_token, only: :ingest
    before_action -> { nav_context(:wiki, :gdrive, :setup, :file_selection) }

    def index
      authorize(current_community, policy_class: FileSelectionPolicy)
      skip_policy_scope
      @config = Config.find_by(community: current_community)
      @auth_policy = AuthPolicy.new(current_user, current_community)
      if @config&.complete?
        @access_token = Wrapper.new(community_id: current_community.id).fresh_access_token
      end
    end

    def ingest
      authorize(current_community, policy_class: FileSelectionPolicy)
      config = Config.find_by(community: current_community)
      batch = FileIngestionBatch.create!(gdrive_config: config, picked: params[:picked])
      FileIngestionJob.perform_later(cluster_id: current_cluster.id, batch_id: batch.id)
      render(json: {batch_id: batch.id})
    end
  end
end
