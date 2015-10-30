require 'rails_helper'

RSpec.describe Household, type: :model do
  context "on create" do
    it "should create an Account" do
      h = create(:household)
      expect(h.account).not_to be_nil
    end
  end

  context "on destroy" do
    it "should destroy Account" do
      h = create(:household)
      h.destroy
      expect(h.account).to be_destroyed
    end
  end
end
