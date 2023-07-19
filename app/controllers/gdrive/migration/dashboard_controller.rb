# frozen_string_literal: true

module GDrive
  module Migration
    class DashboardController < ApplicationController
      before_action -> { nav_context(:wiki, :gdrive) }

      def show
        authorize(current_community, :setup?, policy_class: SetupPolicy)
      end
    end
  end
end
