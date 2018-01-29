FactoryBot.define do
  factory :work_shift, class: "Work::Shift" do
    starts_at "2018-01-28 9:00"
    ends_at "2018-01-28 10:00"
    slots 3
    association :job, factory: :work_job
  end
end
