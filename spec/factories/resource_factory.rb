FactoryGirl.define do
  factory :resource, class: "Reservation::Resource" do
    name "Sitting Room"
    community
  end
end
