# == Schema Information
#
# Table name: meal_restrictions
#
#  id           :bigint           not null, primary key
#  absence      :string           not null
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  contains     :string           not null
#  created_at   :datetime         not null
#  deactivated  :boolean          default(FALSE), not null
#  updated_at   :datetime         not null
#
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
