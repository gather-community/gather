class LineItem < ActiveRecord::Base
  belongs_to :household
  belongs_to :invoice

  scope :incurred_between, ->(a,b){ where("incurred_on >= ? AND incurred_on <= ?", a, b) }
end
