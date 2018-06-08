FactoryBot.define do
  factory :work_reminder, class: 'Work::Reminder' do
    job
    rel_time -180
    abs_time "2018-06-08 10:03:47"
    description "Do stuff"
  end
end
