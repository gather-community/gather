# frozen_string_literal: true

require "rails_helper"

describe Community do
  let(:community) { create(:community) }

  it "generates a calendar token on create" do
    expect(community.calendar_token).to match(/\A[0-9a-zA-Z_-]{20}\z/)
  end

  describe "destruction" do
    context "with dependent models" do
      let(:community) { create(:community) }
      let!(:meal_type) { create(:meal_type, community: community) }
      let!(:subscription) { create(:subscription, community: community) }

      it "destroys them" do
        community.destroy
        expect { meal_type.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { subscription.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
