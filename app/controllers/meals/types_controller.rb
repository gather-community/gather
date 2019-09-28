# frozen_string_literal: true

module Meals
  class TypesController < ApplicationController
    # Only AJAX/JSON for now
    def index
      authorize(sample_type)
      types = policy_scope(Meals::Type).in_community(current_community)
        .matching(params[:search]).active.by_name
      render(json: types, root: "results")
    end

    private

    def sample_type
      Meals::Type.new(community: current_community)
    end
  end
end
