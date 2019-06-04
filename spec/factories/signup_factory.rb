FactoryBot.define do
  factory :signup do
    household
    meal

    trait :with_nums do
      adult_meat { 2 }
      little_kid_veg { 1 }
    end
  end
end
