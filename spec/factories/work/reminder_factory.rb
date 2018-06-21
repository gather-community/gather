FactoryBot.define do
  factory :work_reminder, class: 'Work::Reminder' do
    association :job, factory: :work_job
    rel_time -180
    abs_time "2018-06-08 10:03:47"
    note "Do stuff"
  end
end
