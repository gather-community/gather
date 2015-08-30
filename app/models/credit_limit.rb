class CreditLimit < ActiveRecord::Base
  belongs_to :household
  belongs_to :community
end
