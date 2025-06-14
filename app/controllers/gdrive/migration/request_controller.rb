# frozen_string_literal: true

module GDrive
  module Migration
    class RequestController < ApplicationController
      USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo?access_token="

      # These are public pages. Authentication comes from the token in the query string.
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      # For signed-in pages, we redirect to the appropriate community.
      # Here we should 404 if no community, except for the callback endpoint
      before_action :ensure_community

      before_action :load_and_check_request, except: [:opt_out_complete]

      decorates_assigned :migration_request

      def intro
        if migration_request.opted_out?
          render("opted_out")
        elsif !params[:ignore_mobile] && Browser.new(request.user_agent).device.mobile?
          render("mobile_warning")
        end
      end

      def opt_out
        @untransferred_files = @migration_request.operation.files.where(owner: @migration_request.google_email, status: "pending")
          .order(:name).page(params[:page])
      end

      def confirm_opt_out
        @migration_request.update!(status: "opted_out", opt_out_reason: params[:gdrive_migration_request][:opt_out_reason])
        @migration_request.operation.files.where(owner: @migration_request.google_email, status: "pending").update_all(status: "declined")
        redirect_to gdrive_migration_request_opt_out_complete_path
      end

      def confirm_opt_out
        @migration_request.update!(status: "opted_out", opt_out_reason: params[:gdrive_migration_request][:opt_out_reason])
        @migration_request.operation.files.where(owner: @migration_request.google_email, status: "pending").update_all(status: "declined")
        redirect_to gdrive_migration_request_path
      end

      def un_opt_out
        @migration_request.update!(status: "opened", opt_out_reason: nil)
        @migration_request.operation.files.where(owner: @migration_request.google_email, status: "declined").update_all(status: "pending")
        redirect_to gdrive_migration_request_path
      end

      private

      def load_and_check_request
        @migration_request = Request.find_by!(token: params[:token])
        @migration_request.update!(status: "opened") if @migration_request.new?
        @operation = @migration_request.operation
        @community = @operation.community
      end

      def ensure_community
        render_not_found unless current_community
      end
    end
  end
end
