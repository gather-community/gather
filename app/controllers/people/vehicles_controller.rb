# frozen_string_literal: true

module People
  class VehiclesController < ApplicationController
    before_action -> { nav_context(:people, :vehicles) }

    decorates_assigned :vehicles

    def index
      authorize(sample_vehicle)
      @vehicles = policy_scope(Vehicle).for_community(current_community).by_make_model
    end

    private

    def sample_vehicle
      Vehicle.new(household: Household.new(community: current_community))
    end
  end
end
