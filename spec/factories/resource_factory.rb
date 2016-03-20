FactoryGirl.define do
  factory :resource, class: Reservations::Resource do
    name "Sitting Room"
    community
  end
end
