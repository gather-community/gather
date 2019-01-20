FactoryBot.define do
  factory :work_period, class: "Work::Period" do
    sequence(:name) { |n| "#{Faker::Lorem.word.capitalize} #{n}" }
    starts_on { Date.new(2018, 1, 1) }
    ends_on { starts_on + 30.days }
    community { Defaults.community }
    pick_type "free_for_all"
  end
end
