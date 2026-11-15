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
FactoryBot.define do
  factory :pet, class: "People::Pet" do
    name { Faker::Name.first_name }
    species { Faker::Pet.species }
    color { Faker::Color.common_color_name }
  end
end
