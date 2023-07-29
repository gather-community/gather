# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class FilesController < ApplicationController
        before_action -> { nav_context(:wiki, :gdrive, :migration, :dashboard) }

        def index
          @main_config = MainConfig.find_by(community: current_community)
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          skip_policy_scope
          @migration_config = MigrationConfig.find_by(community: current_community)
          @operation = @migration_config.operations.order(created_at: :desc).first
          @latest_scan = @operation.scans.order(created_at: :desc).first
          @files = @operation.files.page(params[:page])
        end
      end
    end
  end
end
