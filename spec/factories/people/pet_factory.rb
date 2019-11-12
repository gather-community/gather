# frozen_string_literal: true

FactoryBot.define do
  factory :pet, class: "People::Pet" do
    name { Faker::Name.first_name }
    species { %w[Schnauzer Aussie Cat Snake Parrot Lab Newfoundland].sample }
    color { Faker::Color.color_name.capitalize }
  end
end
