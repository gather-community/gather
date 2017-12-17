FactoryBot.define do
  factory :vehicle, class: "People::Vehicle" do
    color { Faker::Color.color_name.capitalize }
    make { Faker::Car.make }
    model { Faker::Car.model }
    plate { ('a'..'z').to_a.shuffle[0,3].join.upcase << rand(1000..9999).to_s }
  end
end
