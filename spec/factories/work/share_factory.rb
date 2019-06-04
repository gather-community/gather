FactoryBot.define do
  factory :work_share, class: "Work::Share" do
    association :period, factory: :work_period
    user
    portion { 1.0 }
  end
end
