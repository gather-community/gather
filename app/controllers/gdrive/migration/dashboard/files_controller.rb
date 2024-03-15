# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class FilesController < ApplicationController
        before_action -> { nav_context(:files, :gdrive, :migration, :dashboard, :files) }

        def index
          @main_config = MainConfig.find_by(community: current_community)
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          skip_policy_scope
          @migration_config = MigrationConfig.find_by(community: current_community)
          @operation = @migration_config.active_operation
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @stats = Stats.new(operation: @operation)
          prepare_lenses({"gdrive/migration/owner": {owners: @stats.owners}}, :"gdrive/migration/status")

          @files = @operation.files.order(modified_at: :desc).page(params[:page]).per(50)
          @files = @files.owned_by(lenses[:owner].selection) if lenses[:owner].active?
          @files = @files.with_status(lenses[:status].selection) if lenses[:status].active?

          @any_errors = @files.any?(&:errored?)
        end
      end
    end
  end
end
