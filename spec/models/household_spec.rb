# frozen_string_literal: true

require "rails_helper"

describe Household do
  describe "unit_num_and_suffix transformation" do
    let(:household) { create(:household, unit_num_and_suffix: unit_num_and_suffix) }
    subject(:pair) { [household.unit_num, household.unit_suffix] }

    context "digits only" do
      let(:unit_num_and_suffix) { "12" }
      it { is_expected.to eq([12, nil]) }
    end

    context "letters only" do
      let(:unit_num_and_suffix) { "A" }
      it { is_expected.to eq([nil, "A"]) }
    end

    context "various characters only" do
      let(:unit_num_and_suffix) { "*" }
      it { is_expected.to eq([nil, "*"]) }
    end

    context "digits and letters" do
      let(:unit_num_and_suffix) { "12A" }
      it { is_expected.to eq([12, "A"]) }
    end

    context "digits and letters with space" do
      let(:unit_num_and_suffix) { "12 A" }
      it { is_expected.to eq([12, "A"]) }
    end

    context "digits and letters with hyphen and extra space" do
      let(:unit_num_and_suffix) { " 12-A " }
      it { is_expected.to eq([12, "-A"]) }
    end

    context "digits and various characters" do
      let(:unit_num_and_suffix) { "12*&^" }
      it { is_expected.to eq([12, "*&^"]) }
    end

    context "letters before digits" do
      let(:unit_num_and_suffix) { "A12" }
      it { is_expected.to eq([nil, "A12"]) }
    end

    context "nothing" do
      let(:unit_num_and_suffix) { nil }
      it { is_expected.to eq([nil, nil]) }
    end

    context "empty string" do
      let(:unit_num_and_suffix) { "" }
      it { is_expected.to eq([nil, nil]) }
    end

    context "space only" do
      let(:unit_num_and_suffix) { "  " }
      it { is_expected.to eq([nil, nil]) }
    end
  end

  # ADD SPEC FOR UNIT NUM AND SUFFIX READER, CHECK DECORATOR
end
