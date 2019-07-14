# frozen_string_literal: true

require "rails_helper"

describe Meals::FormulaPart do
  describe "validation" do
    describe "share numericality" do
      subject(:part) { build(:meal_formula_part, share_formatted: share_formatted) }

      context "percentage" do
        let(:share_formatted) { "10%" }
        it { is_expected.to be_valid }
      end
    end
  end
end
