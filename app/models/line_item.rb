class LineItem < ActiveRecord::Base
  belongs_to :household
  belongs_to :invoice

  scope :incurred_between, ->(a,b){ where("incurred_on >= ? AND incurred_on <= ?", a, b) }

  after_create do
    household.change_balance!(amount)
  end

  after_destroy do
    household.change_balance!(-amount)
  end
end
