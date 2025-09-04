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
require "rails_helper"

# See Work::JobReminder spec for coverage of parent class behaviors.
describe Meals::RoleReminder do
  include_context "reminders"

  describe "RoleReminderDelivery creation" do
    let(:head_cook_role) { create(:meal_role, :head_cook) }
    let(:asst_cook_role) { create(:meal_role, title: "Assistant Cook") }
    let(:formula) { create(:meal_formula, roles: [head_cook_role, asst_cook_role]) }
    # We shouldn't need to assign roles to anyone since Deliveries are made based on role/meal combo.
    let!(:meals) { create_list(:meal, 3, formula: formula) }
    let!(:reminder1) { create_meal_role_reminder(head_cook_role, 2, "days_before") }
    let!(:reminder2) { create_meal_role_reminder(asst_cook_role, 3, "days_before") }
    subject(:deliveries) { Meals::RoleReminderDelivery.all.to_a }

    it "creates deliveries on creation" do
      expect(deliveries.map { |d| [d.meal, d.reminder] }).to contain_exactly(
        [meals[0], reminder1], [meals[1], reminder1], [meals[2], reminder1],
        [meals[0], reminder2], [meals[1], reminder2], [meals[2], reminder2]
      )
    end
  end
end
