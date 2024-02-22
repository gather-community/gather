# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class OwnersController < ApplicationController
        before_action -> { nav_context(:files, :gdrive, :migration, :dashboard, :owners) }

        def index
          @main_config = MainConfig.find_by(community: current_community)
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          skip_policy_scope
          load_operation
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @stats = Stats.new(operation: @operation)
        end

        def show
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          load_operation
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @stats = Stats.new(operation: @operation)
          @owner_id = params[:id]
          @consent_requests = @operation.consent_requests.where(google_email: @owner_id).order(:created_at).all
        end

        def request_consent
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          load_operation
          google_emails = params[:b_ids]
          ConsentRequestJob.perform_later(
            cluster_id: current_community.cluster_id,
            operation_id: @operation.id,
            google_emails: google_emails
          )
          flash[:success] = "Consent requests will be sent momentarily."
          redirect_to(gdrive_migration_dashboard_owners_path)
        end

        private

        def load_operation
          @migration_config = MigrationConfig.find_by(community: current_community)
          @operation = @migration_config.operations.active.order(created_at: :desc).first
        end
      end
    end
  end
end
