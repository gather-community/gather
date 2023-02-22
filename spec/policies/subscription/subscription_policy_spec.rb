# frozen_string_literal: true

require "rails_helper"

describe Subscription::SubscriptionPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:record) { create(:subscription, community: community) }

    permissions :show? do
      it_behaves_like("permits admins or special role but not regular users", :biller)
    end
  end
end
