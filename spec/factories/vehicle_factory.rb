FactoryGirl.define do
  factory :vehicle, class: "People::Vehicle" do
    color "Blue"
    make "Ford"
    model "F-150"
  end
end
