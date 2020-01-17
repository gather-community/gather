# frozen_string_literal: true

require "rails_helper"

describe Groups::MembershipMaintainer do
  context "on user deactivate" do
    let(:user) { create(:user) }

    context "with group membership" do
      let!(:membership) { create(:group_membership, user: user) }

      it "destroys memberships" do
        user.deactivate
        expect { membership.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with no group membership" do
      it "runs cleanly" do
        user.deactivate
        user.activate
      end
    end
  end
end
