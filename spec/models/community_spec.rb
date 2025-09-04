# frozen_string_literal: true

# == Schema Information
#
# Table name: communities
#
#  id             :integer          not null, primary key
#  abbrv          :string(2)
#  calendar_token :string           not null
#  cluster_id     :integer          not null
#  country_code   :string(2)        default("US"), not null
#  created_at     :datetime         not null
#  name           :string(20)       not null
#  settings       :jsonb
#  slug           :string           not null
#  sso_secret     :string           not null
#  updated_at     :datetime         not null
#
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
      let!(:subscription_intent) { create(:subscription_intent, community: community) }

      it "destroys them" do
        community.destroy
        expect { meal_type.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { subscription.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { subscription_intent.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
