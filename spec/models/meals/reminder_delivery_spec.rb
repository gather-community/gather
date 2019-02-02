# frozen_string_literal: true

require "rails_helper"

describe Meals::ReminderDelivery do
  describe "deliver_at computation" do
    let!(:role) { create(:meal_role, :head_cook, time_type: time_type, shift_start: -70, shift_end: 0) }
    let!(:formula) { create(:meal_formula, roles: [role]) }
    let!(:meal) { create(:meal, formula: formula, served_at: meal_time) }
    let(:delivery) { reminder.deliveries.first }
    subject(:deliver_at) { delivery.deliver_at.iso8601 }

    context "date_time role" do
      let(:time_type) { "date_time" }

      context "zero days" do
        let(:meal_time) { "2018-01-01 12:00" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 0, rel_unit_sign: "days_after") }
        it { is_expected.to eq("2018-01-01T09:00:00Z") }
      end

      context "negative days" do
        let(:meal_time) { "2018-01-03 12:00" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 2, rel_unit_sign: "days_before") }
        it { is_expected.to eq("2018-01-01T09:00:00Z") }
      end

      context "positive days" do
        let(:meal_time) { "2017-12-31 12:00" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 1, rel_unit_sign: "days_after") }
        it { is_expected.to eq("2018-01-01T09:00:00Z") }
      end

      context "negative hours" do
        let(:meal_time) { "2018-01-01 15:00" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 3, rel_unit_sign: "hours_before") }
        # Subtract 3 hours from shift start, which is 70 mins before meal time.
        it { is_expected.to eq("2018-01-01T10:50:00Z") }
      end

      context "positive hours" do
        let(:meal_time) { "2017-12-30 11:00" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 48, rel_unit_sign: "hours_after") }
        it { is_expected.to eq("2018-01-01T09:50:00Z") }
      end

      context "fractional hours" do
        let(:meal_time) { "2017-12-30 11:00" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 3.5, rel_unit_sign: "hours_after") }
        it { is_expected.to eq("2017-12-30T13:20:00Z") }
      end
    end

    context "date_only role" do
      let(:time_type) { "date_only" }

      context "zero days" do
        let(:meal_time) { "2018-01-01" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 0, rel_unit_sign: "days_after") }
        it { is_expected.to eq("2018-01-01T09:00:00Z") }
      end

      context "negative days" do
        let(:meal_time) { "2018-01-05" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 4, rel_unit_sign: "days_before") }
        it { is_expected.to eq("2018-01-01T09:00:00Z") }
      end

      context "positive days" do
        let(:meal_time) { "2017-12-31" }
        let!(:reminder) { create_reminder(role: role, rel_magnitude: 1, rel_unit_sign: "days_after") }
        it { is_expected.to eq("2018-01-01T09:00:00Z") }
      end
    end
  end

  def create_reminder(role:, rel_magnitude:, rel_unit_sign:)
    create(:meal_role_reminder, role: role, rel_magnitude: rel_magnitude, rel_unit_sign: rel_unit_sign)
  end
end
