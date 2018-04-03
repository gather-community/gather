# frozen_string_literal: true

module Work
  # Parent controller for all work controllers.
  class WorkController < ApplicationController
    helper_method :sample_period

    protected

    def sample_period
      Period.new(community: current_community)
    end
  end
end
