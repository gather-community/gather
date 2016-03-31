FactoryGirl.define do
  factory :reservation_protocol, class: "Reservation::Protocol" do
    transient do
      resources []
    end

    kinds nil

    after(:create) do |protocol, evaluator|
      protocol.resources = evaluator.resources
    end
  end
end
