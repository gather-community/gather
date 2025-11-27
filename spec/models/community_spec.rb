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

    describe "groups" do
      context "with a group in only one community" do
        let!(:group) { create(:group, communities: [community]) }

        it "destroys the group via the affiliation" do
          community.destroy
          expect { group.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context "with a group in multiple communities" do
        let!(:group) { create(:group, communities: [community, create(:community)]) }

        it "does not destroy the group" do
          community.destroy
          expect { group.reload }.not_to raise_error
        end
      end
    end

    describe "domains" do
      context "with a domain in only one community" do
        let!(:domain) { create(:domain, communities: [community]) }

        it "destroys the domain" do
          community.destroy
          expect { domain.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context "with a domain in multiple communities" do
        let!(:domain) { create(:domain, communities: [community, create(:community)]) }

        it "does not destroy the domain" do
          community.destroy
          expect { domain.reload }.not_to raise_error
        end
      end
    end
  end
end
