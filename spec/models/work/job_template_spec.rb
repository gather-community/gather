# frozen_string_literal: true

require "rails_helper"

describe Work::JobTemplate do
  describe "normalization" do
    let(:template) { build(:work_job_template, submitted) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, template.send(k)] }.to_h }

    before do
      template.validate
    end

    describe "offsets and hours" do
      context "meal related with offsets and hours" do
        let(:submitted) { {meal: true, shift_start_offset: -90, shift_end_offset: 0, hours: 5} }
        it { is_expected.to eq(meal: true, shift_start_offset: -90, shift_end_offset: 0, hours: 1.5) }
      end

      context "meal related but not date_time with offsets and hours" do
        let(:submitted) do
          {meal: true, time_type: "date_only", shift_start_offset: -90, shift_end_offset: 0, hours: 5}
        end
        it do
          is_expected.to eq(meal: true, time_type: "date_only", shift_start_offset: nil,
                            shift_end_offset: nil, hours: 5)
        end
      end

      context "meal related without offsets" do
        let(:submitted) { {meal: true, shift_start_offset: nil, shift_end_offset: nil, hours: 5} }
        it { is_expected.to eq(meal: true, shift_start_offset: nil, shift_end_offset: nil, hours: 5) }
      end

      context "not meal related with offsets and hours" do
        let(:submitted) { {meal: false, shift_start_offset: -90, shift_end_offset: 0, hours: 5} }
        it { is_expected.to eq(meal: false, shift_start_offset: nil, shift_end_offset: nil, hours: 5) }
      end
    end
  end
end
