# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class LogsController < ApplicationController
        before_action -> { nav_context(:wiki, :gdrive, :migration, :dashboard, :logs) }

        def index
          @config = Config.find_by(community: current_community)
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          skip_policy_scope
          load_operation
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @logs = @operation.logs.order(created_at: :desc).page(params[:page]).per(50)
        end

        private

        def load_operation
          @operation = Operation.find_by(community: current_community)
        end
      end
    end
  end
end
