# frozen_string_literal: true

module GDrive
  module Migration
    class FileSelectionController < ApplicationController
      prepend_before_action :set_current_community_from_query_string
      before_action -> { nav_context(:wiki, :gdrive, :migration, :file_selection) }

      def index
        authorize(current_community, :setup?, policy_class: SetupPolicy)
        skip_policy_scope
        @config = MigrationConfig.find_by(community: current_community)
        @setup_policy = SetupPolicy.new(current_user, current_community)
        if @config&.complete?
          @access_token = Wrapper.new(config: @config).fresh_access_token
        end
      end

      def ingest
        authorize(current_community, :setup?, policy_class: SetupPolicy)
        config = MigrationConfig.find_by(community: current_community)
        batch = FileIngestionBatch.create!(gdrive_config: config, picked: params[:picked])
        FileIngestionJob.perform_later(cluster_id: current_cluster.id, batch_id: batch.id)
        render(json: {batch_id: batch.id})
      end
    end
  end
end
