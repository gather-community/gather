# frozen_string_literal: true

module GDrive
  module Migration
    class OperationsController < ApplicationController
      include Destructible

      before_action -> { nav_context(:wiki, :gdrive) }
      helper_method :sample_operation

      def new
        @operation = sample_operation
        authorize(@operation)
      end

      def edit
        @operation = Operation.find(params[:id])
        authorize(@operation)
      end

      def create
        @operation = Operation.new
        @operation.assign_attributes(operation_params(:create))
        @operation.community = current_community
        authorize(@operation)
        if @operation.save
          scan = @operation.scans.create!(scope: "full")
          scan_task = scan.scan_tasks.create!(folder_id: @operation.src_folder_id)
          FullScanJob.perform_later(cluster_id: ActsAsTenant.current_tenant.id, scan_task_id: scan_task.id)
          flash[:success] = "Migration created successfully. File scan will begin momentarily."
          redirect_to(gdrive_migration_dashboard_home_path)
        else
          render(:new)
        end
      end

      def rescan
        @operation = Operation.find(params[:id])
        authorize(@operation)
        scan = @operation.scans.create!(scope: "full")
        scan_task = scan.scan_tasks.create!(folder_id: @operation.src_folder_id)
        FullScanJob.perform_later(cluster_id: ActsAsTenant.current_tenant.id, scan_task_id: scan_task.id)
        flash[:success] = "Scan initialized and will begin momentarily."
        redirect_to(gdrive_migration_dashboard_home_path)
      end

      def update
        @operation = Operation.find(params[:id])
        authorize(@operation)
        if @operation.update(operation_params(:update))
          flash[:success] = "Migration updated successfully."
          redirect_to(gdrive_migration_dashboard_home_path)
        else
          render(:edit)
        end
      end

      def destroy
        operation = Operation.find(params[:id])
        authorize(operation)
        config = Config.find_by(community: current_community)
        wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
        WebhookRegistrar.stop(operation, wrapper)
        operation.destroy
        flash[:success] = "Operation deleted successfully. No longer monitoring for changes."
        redirect_to(gdrive_home_path)
      end

      protected

      def klass
        Operation
      end

      private

      def sample_operation
        Operation.new(community: current_community)
      end

      # Pundit built-in helper doesn't work due to namespacing
      def operation_params(action)
        params.require(:gdrive_migration_operation).permit(policy(@operation).permitted_attributes(action))
      end
    end
  end
end