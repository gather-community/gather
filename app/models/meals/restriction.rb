module Meals
  class Restriction < ApplicationRecord
    include Deactivatable
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :meals

    validates :contains, :absence, presence: true

  end
end
