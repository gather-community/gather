# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class OwnersController < ApplicationController
        before_action -> { nav_context(:wiki, :gdrive, :migration, :dashboard, :owners) }

        decorates_assigned :migration_request

        def index
          @config = Config.find_by(community: current_community)
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
          @migration_request = @operation.requests.where(google_email: @owner_id).order(:created_at).first
        end

        def send_requests
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          load_operation
          google_emails = params[:b_ids]
          RequestJob.perform_later(
            cluster_id: current_community.cluster_id,
            operation_id: @operation.id,
            google_emails: google_emails
          )
          flash[:success] = "Requests will be sent momentarily. "\
            "If owner has an existing request, a new one won't be sent."
          redirect_to(gdrive_migration_dashboard_owners_path)
        end

        private

        def load_operation
          @operation = Operation.find_by(community: current_community)
        end
      end
    end
  end
end
