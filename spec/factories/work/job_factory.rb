FactoryBot.define do
  factory :work_job, class: "Work::Job" do
    transient do
      shift_slots 3
    end

    association :period, factory: :work_period
    title { Faker::Job.title }
    hours 2
    description { Faker::Lorem.paragraph }

    before(:create) do |job, evaluator|
      if job.shifts.empty?
        job.shifts << FactoryBot.build(:work_shift, job: job, slots: evaluator.shift_slots)
      end
    end
  end
end
