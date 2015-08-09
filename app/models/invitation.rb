# Join model for Meals and Communities
class Invitation < ActiveRecord::Base
  belongs_to :meal
  belongs_to :community
end
