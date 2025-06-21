# frozen_string_literal: true

# == Schema Information
#
# Table name: households
#
#  id             :integer          not null, primary key
#  alternate_id   :string
#  cluster_id     :integer          not null
#  community_id   :integer          not null
#  created_at     :datetime         not null
#  deactivated_at :datetime
#  garage_nums    :string
#  keyholders     :string
#  member_type_id :bigint
#  name           :string(50)       not null
#  unit_num       :integer
#  unit_suffix    :string
#  updated_at     :datetime         not null
#
require "rails_helper"

describe Household do
  describe "unit_num_and_suffix writer" do
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
      it { is_expected.to eq([12, "A"]) }
    end

    context "digits and numeric suffix with space" do
      let(:unit_num_and_suffix) { "12 2A" }
      it { is_expected.to eq([12, "2A"]) }
    end

    context "digits and numeric suffix with hyphen" do
      let(:unit_num_and_suffix) { " 12-2A " }
      it { is_expected.to eq([12, "2A"]) }
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

  describe "#unit_num_and_suffix reader" do
    let(:household) { build(:household, unit_num_and_suffix: input) }

    context "after validation" do
      subject(:output) { household.tap(&:validate).unit_num_and_suffix }

      context "digits only" do
        let(:input) { "  12 " }
        it { is_expected.to eq("12") }
      end

      context "letters only" do
        let(:input) { "A" }
        it { is_expected.to eq("A") }
      end

      context "digits and letters with space" do
        let(:input) { "12 A" }
        it { is_expected.to eq("12-A") }
      end

      context "nothing" do
        let(:input) { "" }
        it { is_expected.to be_nil }
      end
    end

    context "setting unit_num and unit_suffix directly with numeric suffix" do
      let(:household) { create(:household, unit_num: 20, unit_suffix: "3A").reload }

      it "doesn't mess them up" do
        expect(household.unit_num).to eq(20)
        expect(household.unit_suffix).to eq("3A")
      end
    end
  end

  describe "deactivation" do
    let(:household) { create(:household, member_count: 2) }

    it "deactivates users" do
      expect(household.users.map(&:active?)).to eq([true, true])
      household.deactivate
      expect(household.users.map(&:active?)).to eq([false, false])
    end
  end

  describe "destruction" do
    let!(:household) { create(:household, skip_listener_action: :account_create) }

    context "with non-restricted associations" do
      let!(:vehicle) { create(:vehicle, household: household) }
      let!(:emergency_contact) { create(:emergency_contact, household: household) }
      let!(:pet) { create(:pet, household: household) }

      it "destroys cleanly" do
        household.destroy
        expect { household.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with account" do
      let!(:account) { create(:account, household: household) }
      it { expect { household.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with meal signup" do
      let!(:signup) { create(:meal_signup, household: household, diner_counts: [2, 1]) }
      it { expect { household.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end
  end
end
