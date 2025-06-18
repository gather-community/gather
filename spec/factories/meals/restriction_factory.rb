FactoryBot.define do
  factory :restriction, class: 'Meals::Restriction' do
    contains { "Gluten" }
    absence { "Gluten-free" }
    community { Defaults.community }

  end
end
