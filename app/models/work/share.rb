module Work
  class Share < ApplicationRecord
    acts_as_tenant(:cluster)

    belongs_to :period
    belongs_to :user
  end
end
