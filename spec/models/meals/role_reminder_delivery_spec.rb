# frozen_string_literal: true

require "rails_helper"

# This spec just covers the proper subclassing of ReminderDelivery. The details of deliver_at computation
# are covered in the work.
describe Meals::RoleReminderDelivery do
  include_context "reminders"

  let!(:role) { create(:meal_role, :head_cook, time_type: "date_time", shift_start: -70, shift_end: 0) }
  let!(:formula) { create(:meal_formula, roles: [role]) }
  let!(:meal) { create(:meal, formula: formula, served_at: "2018-01-03 12:00") }
  let!(:reminder) { create_meal_role_reminder(role, 2.5, "hours_before") }
  let(:delivery) { reminder.deliveries.first }
  subject(:deliver_at) { delivery.deliver_at.iso8601 }

  it "computes time relative to shift start, not meal start" do
    is_expected.to eq("2018-01-03T08:20:00Z")
  end
end
