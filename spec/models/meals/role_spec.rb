# frozen_string_literal: true

require "rails_helper"

describe Meals::Role do
  describe "normalization" do
    let(:role) { build(:meal_role, submitted) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, role.send(k)] }.to_h }

    before do
      role.validate
    end

    describe "offsets" do
      context "date_only with offsets" do
        let(:submitted) { {time_type: "date_only", shift_start: -90, shift_end: 0} }
        it { is_expected.to eq(time_type: "date_only", shift_start: nil, shift_end: nil) }
      end

      context "date_time with offsets" do
        let(:submitted) { {time_type: "date_time", shift_start: -90, shift_end: 0} }
        it { is_expected.to eq(time_type: "date_time", shift_start: -90, shift_end: 0) }
      end
    end
  end

  describe "validation" do
    describe "shift_time_positive" do
      subject(:role) do
        build(:meal_role, time_type: "date_time", shift_start: shift_start, shift_end: shift_end)
      end

      context "with positive elapsed time" do
        let(:shift_start) { -90 }
        let(:shift_end) { -30 }
        it { is_expected.to be_valid }
      end

      context "with zero elapsed time" do
        let(:shift_start) { 30 }
        let(:shift_end) { 30 }
        it { is_expected.to have_errors(shift_end: /Must be after/) }
      end

      context "with negative elapsed time" do
        let(:shift_start) { 30 }
        let(:shift_end) { -30 }
        it { is_expected.to have_errors(shift_end: /Must be after/) }
      end
    end

    describe "offsets required" do
      subject(:role) do
        build(:meal_role, time_type: time_type)
      end

      context "when date_time" do
        let(:time_type) { "date_time" }
        it { is_expected.to have_errors(shift_start: /can't be blank/, shift_end: /can't be blank/) }
      end

      context "when not date_time" do
        let(:time_type) { "date_only" }
        it { is_expected.to be_valid }
      end
    end
  end
end
