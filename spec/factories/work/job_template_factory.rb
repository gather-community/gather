# frozen_string_literal: true

FactoryBot.define do
  factory :work_job_template, class: "Work::JobTemplate" do
    sequence(:title) { |n| "#{Faker::Job.title} #{n}" }
    hours { 2 }
    community { default_community }
    description { Faker::Lorem.paragraph }
  end
end
