FactoryBot.define do
  factory :work_job, class: "Work::Job" do
    association :period, factory: :work_period
    title { Faker::Job.title }
    hours 2
    description { Faker::Lorem.paragraph }
    community { default_community }

    before(:create) do |job|
      if job.shifts.empty?
        job.shifts << FactoryBot.build(:work_shift, job: job)
      end
    end
  end
end
