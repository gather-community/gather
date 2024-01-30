# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class OwnersController < ApplicationController
        before_action -> { nav_context(:wiki, :gdrive, :migration, :dashboard, :owners) }

        def index
          @main_config = MainConfig.find_by(community: current_community)
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          skip_policy_scope
          @migration_config = MigrationConfig.find_by(community: current_community)
          @operation = @migration_config.operations.active.order(created_at: :desc).first
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @stats = Stats.new(operation: @operation)
        end

        def show
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          @migration_config = MigrationConfig.find_by(community: current_community)
          @operation = @migration_config.operations.active.order(created_at: :desc).first
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @stats = Stats.new(operation: @operation)
          @owner_id = params[:id]
          @consent_requests = @operation.consent_requests.where(google_email: @owner_id).order(:created_at).all
        end
      end
    end
  end
end
