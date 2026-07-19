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

  it "upcases country_code on save" do
    community = create(:community, country_code: "gb")
    expect(community.country_code).to eq("GB")
  end

  describe "#status" do
    # Sets a subscription with the given cached detailed_status signals.
    def subscribe(stripe_status:, **signals)
      create(:subscription, community: community, stripe_status: stripe_status,
        synced_at: Time.current, **signals)
    end

    it "is :trial with no subscription" do
      expect(community.status).to eq(:trial)
    end

    it "is :subscribed with a healthy subscription" do
      subscribe(stripe_status: "active", payment_intent_status: "succeeded")
      expect(community.reload.status).to eq(:subscribed)
    end

    it "is :subscribed while a signup is in progress (incomplete)" do
      subscribe(stripe_status: "incomplete", payment_intent_status: "requires_payment_method")
      expect(community.reload.status).to eq(:subscribed)
    end

    it "is :problem when the subscription is past_due/canceled/unpaid/expired" do
      subscribe(stripe_status: "canceled")
      expect(community.reload.status).to eq(:problem)
    end

    it "is :trial when the subscription has never synced" do
      create(:subscription, community: community) # synced_at nil => :unknown
      expect(community.reload.status).to eq(:trial)
    end

    it "prefers :warning over :problem" do
      subscribe(stripe_status: "canceled")
      community.update!(inactivity_warning_count: 1)
      expect(community.reload.status).to eq(:warning)
    end

    it "prefers :deactivated over everything" do
      subscribe(stripe_status: "active", payment_intent_status: "succeeded")
      community.update!(deactivated_at: Time.current, inactivity_warning_count: 1)
      expect(community.reload.status).to eq(:deactivated)
    end
  end

  describe "#default_currency" do
    it "maps a supported country code to its currency" do
      expect(build(:community, country_code: "CA").default_currency).to eq("cad")
    end

    it "is nil for an unsupported country code" do
      expect(build(:community, country_code: "ZZ").default_currency).to be_nil
    end
  end

  describe "messaging accounts" do
    let!(:account) { create(:messaging_account, community: community) }

    it "are destroyed with the community" do
      community.destroy
      expect { account.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "destruction" do
    context "with dependent models" do
      let!(:meal_type) { create(:meal_type, community: community) }
      let!(:subscription) { create(:subscription, community: community) }

      it "destroys them" do
        community.destroy
        expect { meal_type.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { subscription.reload }.to raise_error(ActiveRecord::RecordNotFound)
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

  describe "#billable_seat_count" do
    let(:community) { create(:community) }

    it "counts real, active, full-access adults and excludes the rest" do
      create(:user, community: community) # counted
      create(:user, community: community) # counted
      create(:user, :child, community: community) # excluded: child (not an adult, no full access)
      create(:user, :inactive, community: community) # excluded: deactivated
      create(:user, community: community, fake: true) # excluded: sample data

      expect(community.billable_seat_count).to eq(2)
    end
  end
end
