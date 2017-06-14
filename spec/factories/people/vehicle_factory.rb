FactoryGirl.define do
  factory :vehicle, class: "People::Vehicle" do
    color { Faker::Color.color_name.capitalize }
    make { Faker::Car.make }
    model { Faker::Car.model }
  end
end
