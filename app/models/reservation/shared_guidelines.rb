class Reservation::SharedGuidelines < ActiveRecord::Base
  acts_as_tenant(:cluster)
  belongs_to :community
end
