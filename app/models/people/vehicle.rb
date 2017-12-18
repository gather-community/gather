module People
  class Vehicle < ApplicationRecord
    acts_as_tenant(:cluster)

    belongs_to :household, inverse_of: :vehicles

    normalize_attributes :make, :model, :color, :plate

    before_validation { self.plate = plate.try(:upcase).try(:gsub, /[^A-Z0-9 ]/, "") }

    validates :make, :model, :color, presence: true

    def to_s
      "#{color} #{make} #{model}".tap do |str|
        str << " (#{plate})" if plate.present?
      end
    end
  end
end
