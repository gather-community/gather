module People
  class Pet < ActiveRecord::Base
    acts_as_tenant(:cluster)

    belongs_to :household, inverse_of: :pets
    normalize_attributes :caregivers, :color, :name, :species, :vet, :health_issues
    validates :color, :name, :species, presence: true
  end
end
