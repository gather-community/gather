class LineItem < ActiveRecord::Base
  belongs_to :household

  after_create do
    household.change_balance!(amount)
  end

  after_destroy do
    household.change_balance!(-amount)
  end
end
