module Work
  class Assignment < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :job
    belongs_to :user
  end
end
