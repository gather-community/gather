# frozen_string_literal: true

# == Schema Information
#
# Table name: people_vehicles
#
#  id           :integer          not null, primary key
#  color        :string
#  make         :string
#  model        :string
#  plate        :string(10)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :integer          not null
#  household_id :integer          not null
#
# Indexes
#
#  index_people_vehicles_on_cluster_id    (cluster_id)
#  index_people_vehicles_on_household_id  (household_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (household_id => households.id)
#
module People
  class Vehicle < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :household, inverse_of: :vehicles

    scope :in_community, ->(c) { joins(:household).where(households: {community_id: c.id}) }
    scope :by_make_model, -> { alpha_order(:make, :model, :color, :plate) }
    scope :active, -> { joins(:household).merge(Household.active) }

    normalize_attributes :make, :model, :color, :plate

    before_validation { self.plate = plate.try(:upcase).try(:gsub, /[^A-Z0-9 ]/, "") }

    validates :make, :model, :color, presence: true

    delegate :community, to: :household
    delegate :name, to: :household, prefix: true

    def to_s
      str = +"#{color} #{make} #{model}"
      str << " (#{plate})" if plate.present?
      str
    end
  end
end
