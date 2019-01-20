FactoryBot.define do
  factory :reservation_protocol, class: "Reservations::Protocol" do
    transient do
      resources []
    end

    sequence(:name) { |i| "Protocol #{i}" }
    kinds nil
    community { resources.first.try(:community) || Defaults.community }

    after(:create) do |protocol, evaluator|
      protocol.resources = evaluator.resources
    end
  end
end
