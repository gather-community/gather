class People::Group < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :community
end
