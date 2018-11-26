# frozen_string_literal: true

module Meals
  # Models a single line within an order, including the desired item, quantity, size, and any options.
  # Will eventually be an AR model once future refactoring is complete.
  class Line
    attr_accessor :id, :item_id, :quantity, :_destroy

    def initialize(id: nil, item_id: nil, quantity: 1, _destroy: false)
      self.id = id
      self.item_id = item_id
      self.quantity = quantity
      self._destroy = _destroy
    end

    def new_record?
      id.nil?
    end

    def persisted?
      !new_record?
    end

    def marked_for_destruction?
      ["true", "1", true, 1].include?(_destroy)
    end
  end
end
