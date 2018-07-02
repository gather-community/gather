module People
  class Vehicle < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :household, inverse_of: :vehicles

    scope :in_community, ->(c) { joins(:household).where(households: {community_id: c.id}) }
    scope :by_make_model, -> { order("LOWER(make)", "LOWER(model)", "LOWER(color)", "LOWER(plate)") }
    scope :active, -> { joins(:household).merge(Household.active) }

    normalize_attributes :make, :model, :color, :plate

    before_validation { self.plate = plate.try(:upcase).try(:gsub, /[^A-Z0-9 ]/, "") }

    validates :make, :model, :color, presence: true

    delegate :community, to: :household
    delegate :name, to: :household, prefix: true

    def to_s
      "#{color} #{make} #{model}".tap do |str|
        str << " (#{plate})" if plate.present?
      end
    end
  end
end
