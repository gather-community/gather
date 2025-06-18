require 'rails_helper'

RSpec.describe Meals::Restriction, type: :model do
  describe "validation" do
    describe "must have both contains and absence" do
      subject(:restriction) { build(:restriction, contains: contains, absence: absence) }

      context "no absence" do
        let(:contains) { "gluten" }
        let(:absence) { nil }
        it { is_expected.to be_invalid }
      end

      context "no contains" do
        let(:contains) { nil }
        let(:absence) { "No gluten" }
        it { is_expected.to be_invalid }
      end

      context "has both" do
        let(:contains) { "Gluten" }
        let(:absence) { "No gluten" }
        it { is_expected.to be_valid }
      end
    end

  end

end
