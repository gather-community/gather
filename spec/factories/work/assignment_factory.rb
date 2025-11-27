# frozen_string_literal: true

# == Schema Information
#
# Table name: work_assignments
#
#  id          :bigint           not null, primary key
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  preassigned :boolean          default(FALSE), not null
#  shift_id    :integer          not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
FactoryBot.define do
  factory :work_assignment, class: "Work::Assignment" do
    association :shift, factory: :work_shift
    user
  end
end
