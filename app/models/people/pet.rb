# frozen_string_literal: true

# == Schema Information
#
# Table name: people_pets
#
#  id            :integer          not null, primary key
#  caregivers    :string
#  cluster_id    :integer          not null
#  color         :string
#  created_at    :datetime         not null
#  health_issues :text
#  household_id  :integer          not null
#  name          :string
#  species       :string
#  updated_at    :datetime         not null
#  vet           :string
#
module People
  class Pet < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :household, inverse_of: :pets
    normalize_attributes :caregivers, :color, :name, :species, :vet, :health_issues
    validates :color, :name, :species, presence: true
  end
end
