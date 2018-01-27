FactoryBot.define do
  factory :people_group, class: 'People::Group' do
    name { Faker::Lorem.word.capitalize }
    community { default_community }
  end
end
