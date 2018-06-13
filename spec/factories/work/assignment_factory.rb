FactoryBot.define do
  factory :work_assignment, class: 'Work::Assignment' do
    association :shift, factory: :work_shift
    user
  end
end
