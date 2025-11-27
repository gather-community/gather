# frozen_string_literal: true

# == Schema Information
#
# Table name: reminders
#
#  id            :bigint           not null, primary key
#  abs_rel       :string           default("relative"), not null
#  abs_time      :datetime
#  cluster_id    :integer          not null
#  created_at    :datetime         not null
#  job_id        :bigint
#  note          :string
#  rel_magnitude :decimal(10, 2)
#  rel_unit_sign :string
#  role_id       :bigint
#  type          :string           not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :work_job_reminder, class: "Work::JobReminder" do
    association :job, factory: :work_job
    note { "Do stuff" }
    abs_rel { "absolute" }

    after(:build) do |reminder|
      reminder.abs_time ||= "2018-01-01 12:00" if reminder.abs_rel == "absolute"
    end
  end
end
