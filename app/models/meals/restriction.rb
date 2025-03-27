module Meals
  class Restriction < ApplicationRecord

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :meals

    validates :contains, :absence, presence: true

    before_validation :set_deactivated_at

    def deactivated?
      deactivated
    end
  end
end
