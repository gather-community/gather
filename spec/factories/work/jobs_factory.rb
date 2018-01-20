FactoryBot.define do
  factory :work_job, class: "Work::Job" do
    association :period, factory: :work_period
    title { Faker::Job.title }
    hours 2
    association :requester, factory: :people_group
    description { Faker::Lorem.paragraph }
    community
    cluster
  end
end
