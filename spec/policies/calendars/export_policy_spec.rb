# frozen_string_literal: true

require "rails_helper"

describe Calendars::ExportPolicy do
  describe "permissions" do
    include_context "policy permissions"

    permissions :index?, :personalized?, :reset_token? do
      it "permits active users" do
        expect(subject).to permit(user, Calendars::Exports::Export.new(user: user))
      end

      it "raises error if no user" do
        expect do
          Calendars::ExportPolicy.new(nil, Calendars::Exports::Export.new(user: user))
        end.to raise_error(Pundit::NotAuthorizedError)
      end

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, Calendars::Exports::Export.new(user: inactive_user))
      end
    end

    permissions :community? do
      let(:record) { Calendars::Exports::Export.new(community: community) }
      subject(:policy_obj) { Calendars::ExportPolicy.new(nil, record, community_token: token) }

      context "with correct token" do
        let(:token) { community.calendar_token }
        it { expect(policy_obj.community?).to be(true) }
      end

      context "with incorrect token" do
        let(:token) { "628ab7dc26628ab7dc26" }
        it { expect(policy_obj.community?).to be(false) }
      end
    end
  end
end
