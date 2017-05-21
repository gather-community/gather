# Join model for Meals and Communities
class Invitation < ActiveRecord::Base
  acts_as_tenant(:cluster)

  belongs_to :meal
  belongs_to :community
end
