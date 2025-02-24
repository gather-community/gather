# frozen_string_literal: true

# A lens is a set of parameters that scope an index listing, e.g. search, filter, pagination.
module Lensable
  extend ActiveSupport::Concern

  included do
    attr_reader :lenses

    helper_method :lenses
  end

  def prepare_lenses(*lens_names)
    @lenses = Lens::Set.new(context: self, lens_names: lens_names, route_params: params)
  end

  def update_lenses_and_quit(*lens_names)
    prepare_lenses(*lens_names)
    skip_policy_scope
    head(:ok)
  end
end
