# frozen_string_literal: true

module GDrive
  module Migration
    module Dashboard
      class StatusController < ApplicationController
        before_action -> { nav_context(:wiki, :gdrive, :migration, :dashboard, :status) }

        def show
          authorize(current_community, :setup?, policy_class: SetupPolicy)
          @config = Config.find_by(community: current_community)
          @operation = Operation.find_by(community: current_community)
          @latest_scan = @operation.scans.full.order(created_at: :desc).first
          @stats = Stats.new(operation: @operation)
        end
      end
    end
  end
end
