FactoryGirl.define do
  factory :resource, class: "Reservation::Resource" do
    sequence(:name){ |n| "Resource #{n}" }
    community { default_community }
  end
end
