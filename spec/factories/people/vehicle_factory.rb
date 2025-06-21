# frozen_string_literal: true

# == Schema Information
#
# Table name: people_vehicles
#
#  id           :integer          not null, primary key
#  cluster_id   :integer          not null
#  color        :string
#  created_at   :datetime         not null
#  household_id :integer          not null
#  make         :string
#  model        :string
#  plate        :string(10)
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :vehicle, class: "People::Vehicle" do
    color { Faker::Color.color_name.capitalize }
    make { Faker::Car.make }
    model { Faker::Car.model }
    plate { ("a".."z").to_a.sample(3).join.upcase << rand(1000..9999).to_s }
  end
end
