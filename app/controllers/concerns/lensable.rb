# A lens is a set of parameters that scope an index listing, e.g. search, filter, pagination.
module Lensable
  extend ActiveSupport::Concern

  included do
    attr_reader :lens
    helper_method :lens
  end

  def prepare_lens(*fields)
    @lens = Lens.new(controller: self, fields: fields, store: (session[:lenses] ||= {}), params: params)
  end

  # Models a set of parameters and parameter values that scope an index view.
  # `controller` - The calling controller.
  # `fields` - The names of the fields that make up the lens, e.g. [:community, :search].
  # `store` - A reference to an existing session hash chunk where the data will live.
  # `params` - The Rails params hash.
  class Lens
    attr_accessor :fields, :store, :params, :values

    def initialize(controller:, fields:, store:, params:)
      self.fields = fields
      self.store = store

      # Prepare the store.
      store[controller.controller_name] ||= {}
      self.values = store[controller.controller_name][controller.action_name] ||= {}

      # Copy lens params from the params hash.
      fields.each do |f|
        self[f] = params[f] if params.has_key?(f)
      end
    end

    def blank?
      fields.none? { |f| self[f].present? }
    end

    def [](key)
      # Convert to string because the session hash uses strings.
      values[key.to_s]
    end

    def []=(key, value)
      values[key.to_s] = value
    end
  end
end
