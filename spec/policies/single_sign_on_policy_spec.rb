# frozen_string_literal: true

require "rails_helper"

describe SingleSignOnPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:user) { create(:user, community: community) }

    permissions :sign_on? do
      it "permits active users in community" do
        expect(subject).to permit(user, community)
      end

      it "forbids active users in other community" do
        expect(subject).not_to permit(user, communityB)
      end

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, community)
      end
    end
  end
end
