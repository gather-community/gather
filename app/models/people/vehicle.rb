module People
  class Vehicle < ActiveRecord::Base
    acts_as_tenant(:cluster)

    belongs_to :household, inverse_of: :vehicles

    normalize_attributes :make, :model, :color
    validates :make, :model, :color, presence: true

    def to_s
      "#{color} #{make} #{model}"
    end
  end
end
