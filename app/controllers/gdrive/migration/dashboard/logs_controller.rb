# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class LogsController < ApplicationController
        before_action -> { nav_context(:wiki, :gdrive, :migration, :dashboard, :logs) }

        def index
          @main_config = MainConfig.find_by(community: current_community)
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          skip_policy_scope
          load_operation
          @logs = @operation.logs.order(created_at: :desc).page(params[:page]).per(50)
        end

        private

        def load_operation
          @migration_config = MigrationConfig.find_by(community: current_community)
          @operation = @migration_config.active_operation
        end
      end
    end
  end
end
