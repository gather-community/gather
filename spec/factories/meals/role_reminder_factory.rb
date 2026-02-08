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
  factory :meal_role_reminder, class: "Meals::RoleReminder" do
    association :role, factory: :meal_role
    note { "Do stuff" }
    rel_unit_sign { "days_before" }
    rel_magnitude { 2 }
  end
end
