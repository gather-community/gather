# frozen_string_literal: true

# == Schema Information
#
# Table name: people_pets
#
#  id            :integer          not null, primary key
#  caregivers    :string
#  color         :string
#  health_issues :text
#  name          :string
#  species       :string
#  vet           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  cluster_id    :integer          not null
#  household_id  :integer          not null
#
# Indexes
#
#  index_people_pets_on_cluster_id    (cluster_id)
#  index_people_pets_on_household_id  (household_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (household_id => households.id)
#
module People
  class Pet < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :household, inverse_of: :pets
    normalize_attributes :caregivers, :color, :name, :species, :vet, :health_issues
    validates :color, :name, :species, presence: true
  end
end
