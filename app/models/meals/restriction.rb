module Meals
  class Restriction < ApplicationRecord
    include Deactivatable

    attribute :deactivated, :boolean

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :meals

    validates :contains, :absence, presence: true

    def deactivated? 
      deactivated_at.present? && deactivated_at != 0
    end

  end
end
