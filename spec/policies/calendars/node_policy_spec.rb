# frozen_string_literal: true

require "rails_helper"

describe Calendars::NodePolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:node) { create(:calendar) }
    let(:record) { node }

    permissions :index? do
      it_behaves_like "permits admins but not regular users"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Calendars::Node }
    let!(:calendar1) { create(:calendar) }
    let!(:group1) { create(:calendar_group) }
    let!(:calendar2) { create(:calendar) }
    let!(:calendar3) { create(:calendar) }
    let!(:calendar4) { create(:calendar, :inactive) }
    let!(:protocol1) { create(:calendar_protocol, calendars: [calendar1], other_communities: "forbidden") }
    let!(:protocol2) { create(:calendar_protocol, calendars: [calendar2], other_communities: "read_only") }

    context "for insiders, returns group and all active calendars" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(group1, calendar1, calendar2, calendar3) }
    end

    context "for outsiders, returns group and only non-forbidden calendars" do
      let(:actor) { userB }
      it { is_expected.to contain_exactly(group1, calendar2, calendar3) }
    end

    context "for admins, returns group and all calendars" do
      let(:actor) { admin }
      it { is_expected.to contain_exactly(group1, calendar1, calendar2, calendar3, calendar4) }
    end
  end
end
