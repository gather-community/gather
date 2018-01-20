class Work::Job < ApplicationRecord
  acts_as_tenant :cluster
end
