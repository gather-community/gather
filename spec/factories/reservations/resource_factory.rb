FactoryGirl.define do
  factory :resource, class: "Reservations::Resource" do
    sequence(:name) { |n| "Resource #{n}" }
    community { default_community }
  end
end
