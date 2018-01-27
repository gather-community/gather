module Work
  class Period < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
  end
end
