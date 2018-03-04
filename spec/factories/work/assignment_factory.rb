FactoryBot.define do
  factory :work_assignment, class: 'Work::Assignment' do
    association :job, factory: :work_job
    user
  end
end
