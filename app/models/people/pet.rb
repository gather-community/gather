# frozen_string_literal: true

module People
  class Pet < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :household, inverse_of: :pets
    normalize_attributes :caregivers, :color, :name, :species, :vet, :health_issues
    validates :color, :name, :species, presence: true
  end
end
