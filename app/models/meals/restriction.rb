module Meals
  class Restriction < ApplicationRecord
    include Deactivatable

    attribute :disabled, :boolean

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :meals

    validates :contains, :absence, presence: true

    def disabled? 
      deactivated_at.present? && deactivated_at != 0
    end

  end
end
