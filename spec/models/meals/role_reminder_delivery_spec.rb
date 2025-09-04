# frozen_string_literal: true

# == Schema Information
#
# Table name: reminder_deliveries
#
#  id          :bigint           not null, primary key
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  deliver_at  :datetime         not null
#  meal_id     :bigint
#  reminder_id :integer          not null
#  shift_id    :bigint
#  type        :string           not null
#  updated_at  :datetime         not null
#
require "rails_helper"

describe Meals::RoleReminderDelivery do
  include_context "reminders"

  let(:yr_mo) { Time.zone.today.strftime("%Y-%m") }
  let!(:hc_role) { create(:meal_role, :head_cook, time_type: "date_time", shift_start: -70, shift_end: 0) }
  let!(:ac_role) { create(:meal_role, title: "Asst", time_type: "date_time", shift_start: -90, shift_end: 0) }
  let!(:decoy) { create(:meal_role) }
  let!(:formula) { create(:meal_formula, roles: [hc_role, ac_role]) }
  let(:meal) { create(:meal, formula: formula, served_at: "#{yr_mo}-04 12:00") }
  let(:hc_reminder) { create_meal_role_reminder(hc_role, 2.5, "hours_before") }
  let(:ac_reminder1) { create_meal_role_reminder(ac_role, 2, "hours_before") }
  let(:ac_reminder2) { create_meal_role_reminder(ac_role, 2, "days_before") }

  # This spec just covers the proper subclassing of ReminderDelivery. The details of deliver_at computation
  # are covered in the work module specs.
  describe "deliver_at computation" do
    subject(:deliver_at) { meal && hc_reminder.deliveries[0].deliver_at.iso8601 }

    it { is_expected.to eq("#{yr_mo}-04T08:20:00Z") }
  end

  describe "#assignments" do
    let!(:meal) { create(:meal, formula: formula) }
    let(:assignments) do
      [meal.assignments[0], # This is created by factory.
       meal.assignments.create!(role: ac_role, user: create(:user)),
       meal.assignments.create!(role: ac_role, user: create(:user))]
    end

    it "is correct for hc_role and ac_role" do
      expect(hc_reminder.deliveries[0].assignments).to match_array([assignments[0]])
      expect(ac_reminder1.deliveries[0].assignments).to match_array(assignments[1..2])
    end
  end
end
