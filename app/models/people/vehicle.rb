class People::Vehicle < ActiveRecord::Base
  acts_as_tenant(:cluster)

  normalize_attributes :make, :model, :color
  validates :make, :model, :color, presence: true

  def to_s
    "#{color} #{make} #{model}"
  end
end
