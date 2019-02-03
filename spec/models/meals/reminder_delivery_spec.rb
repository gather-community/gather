# frozen_string_literal: true

require "rails_helper"

# This spec just covers the proper subclassing of ReminderDelivery. The details of deliver_at computation
# are covered in the work.
describe Meals::ReminderDelivery do
  let!(:role) { create(:meal_role, :head_cook, time_type: "date_time", shift_start: -70, shift_end: 0) }
  let!(:formula) { create(:meal_formula, roles: [role]) }
  let!(:meal) { create(:meal, formula: formula, served_at: "2018-01-03 12:00") }
  let!(:reminder) { create_reminder(role: role, rel_magnitude: 2, rel_unit_sign: "days_before") }
  let(:delivery) { reminder.deliveries.first }
  subject(:deliver_at) { delivery.deliver_at.iso8601 }

  it { is_expected.to eq("2018-01-01T09:00:00Z") }

  def create_reminder(role:, rel_magnitude:, rel_unit_sign:)
    create(:meal_role_reminder, role: role, rel_magnitude: rel_magnitude, rel_unit_sign: rel_unit_sign)
  end
end
