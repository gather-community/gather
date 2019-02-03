# frozen_string_literal: true

require "rails_helper"

# See Work::JobReminder spec for coverage of parent class behaviors.
describe Meals::RoleReminder do
  describe "RoleReminderDelivery creation" do
    let(:head_cook_role) { create(:meal_role, :head_cook) }
    let(:asst_cook_role) { create(:meal_role, title: "Assistant Cook") }
    let(:formula) { create(:meal_formula, roles: [head_cook_role, asst_cook_role]) }
    # We shouldn't need to assign roles to anyone since Deliveries are made based on role/meal combo.
    let!(:meals) { create_list(:meal, 3, formula: formula) }
    let!(:reminder1) { create_reminder(role: head_cook_role, rel_magnitude: 2, rel_unit_sign: "days_before") }
    let!(:reminder2) { create_reminder(role: asst_cook_role, rel_magnitude: 3, rel_unit_sign: "days_before") }
    subject(:deliveries) { Meals::RoleReminderDelivery.all.to_a }

    it "creates deliveries on creation" do
      expect(deliveries.map { |d| [d.meal, d.reminder] }).to contain_exactly(
        [meals[0], reminder1], [meals[1], reminder1], [meals[2], reminder1],
        [meals[0], reminder2], [meals[1], reminder2], [meals[2], reminder2]
      )
    end
  end

  def create_reminder(role:, rel_magnitude:, rel_unit_sign:)
    create(:meal_role_reminder, role: role, rel_magnitude: rel_magnitude, rel_unit_sign: rel_unit_sign)
  end
end
