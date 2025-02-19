module Meals
  class Restriction < ApplicationRecord
    belongs_to :community

    validates :contains, :absence, presence: true

  end
end
