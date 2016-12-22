class People::Vehicle < ActiveRecord::Base
  normalize_attributes :make, :model, :color
  validates :make, :model, :color, presence: true
end
