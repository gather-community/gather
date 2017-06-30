require "rails_helper"

RSpec.describe Signup, type: :model do
  describe "with no signups" do
    context "on create" do
      let(:signup) { build(:signup) }

      it "should delete itself if all zeros" do
        expect(signup).not_to be_valid
        expect(signup.errors[:base].join).to match("must sign up at least")
      end
    end

    context "on update" do
      let(:signup) { create(:signup, adult_veg: 2) }

      it "should delete itself" do
        signup.update_attributes!(adult_veg: 0)
        expect(signup).to be_destroyed
      end
    end
  end
end
