# frozen_string_literal: true

require "rails_helper"

describe "allergen handling" do
  describe "validation" do
    subject(:meal) { build(:meal, :with_menu, allergens: allergens, no_allergens: no_allergens) }

    context "with menu and no_allergens true" do
      let(:no_allergens) { true }

      context "with no other allergens" do
        let(:allergens) { [] }
        it { is_expected.to be_valid }
      end

      context "with other allergens" do
        let(:allergens) { ["Foo"] }
        it { is_expected.to have_errors(allergens: /'None' can't be selected/) }
      end
    end

    context "with menu and no_allergens false" do
      let(:no_allergens) { false }

      context "with no other allergens" do
        let(:allergens) { [] }
        it { is_expected.to have_errors(allergens: /at least one box must be checked/) }
      end

      context "with other allergens" do
        let(:allergens) { ["Foo"] }
        it { is_expected.to be_valid }
      end
    end
  end
end
