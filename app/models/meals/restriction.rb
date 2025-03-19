module Meals
  class Restriction < ApplicationRecord
    include Deactivatable

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :meals

    validates :contains, :absence, presence: true

    before_validation :set_deactivated_at

    def deactivated?
      deactivated
    end

    private 
    def set_deactivated_at
      self.deactivated_at = DateTime.now if deactivated?
    end


  end
end
