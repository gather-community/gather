# frozen_string_literal: true

module Meals
  class Restriction < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :restrictions

    validates :contains, :absence, presence: true

    def deactivated?
      deactivated
    end
  end
end
