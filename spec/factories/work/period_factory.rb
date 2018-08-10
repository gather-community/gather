FactoryBot.define do
  factory :work_period, class: "Work::Period" do
    name { Faker::Lorem.word.capitalize }
    starts_on "2018-01-01"
    ends_on "2018-03-31"
    community { default_community }
    pick_type "free_for_all"
  end
end
