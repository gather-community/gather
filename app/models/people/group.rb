class People::Group < ApplicationRecord
  acts_as_tenant :cluster
end
