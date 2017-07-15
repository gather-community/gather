module Reservations
  class ResourcesController < ApplicationController
    decorates_assigned :resources

    before_action -> { nav_context(:reservations, :resources) }

    def index
      authorize sample_resource
      @resources = policy_scope(Reservations::Resource).where(community: current_community).by_name
    end

    private

    def sample_resource
      @sample_resource ||= Reservations::Resource.new(community: current_community)
    end
  end
end
