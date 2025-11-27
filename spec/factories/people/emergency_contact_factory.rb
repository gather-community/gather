# frozen_string_literal: true

# == Schema Information
#
# Table name: people_emergency_contacts
#
#  id           :integer          not null, primary key
#  alt_phone    :string
#  cluster_id   :integer          not null
#  country_code :string(2)        not null
#  created_at   :datetime         not null
#  email        :string(255)
#  household_id :integer
#  location     :string           not null
#  main_phone   :string           not null
#  name         :string           not null
#  relationship :string           not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :emergency_contact, class: "People::EmergencyContact" do
    alt_phone { rand(3) > 1 ? Faker::PhoneNumber.simple : nil }
    email { rand(10) > 2 ? Faker::Internet.email : nil }
    location { Faker::Address.city }
    main_phone { Faker::PhoneNumber.simple }
    name { Faker::Name.name }
    relationship { Faker::Relationship.relationship }
    country_code { "US" }
  end
end
