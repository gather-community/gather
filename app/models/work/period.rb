class Work::Period < ApplicationRecord
  acts_as_tenant :cluster
end
