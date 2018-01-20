FactoryBot.define do
  factory :people_group, class: 'People::Group' do
    name { Faker::Lorem.word.capitalize }
  end
end
