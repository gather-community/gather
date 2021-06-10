# frozen_string_literal: true

require "rails_helper"

describe Calendars::ProtocolPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:protocol) { create(:calendar_protocol) }
    let(:record) { protocol }

    permissions :index? do
      it_behaves_like "permits users in cluster"
    end

    permissions :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins but not regular users"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Calendars::Protocol }
    let!(:objs_in_community) { create_list(:calendar_protocol, 2) }
    let!(:objs_in_cluster) { create_list(:calendar_protocol, 2, community: communityB) }

    it_behaves_like "permits only admins in community"
  end

  describe "permitted_attributes" do
    include_context "policy permissions"
    let(:actor) { create(:admin) }
    let(:protocol) { create(:calendar_protocol) }
    let(:basic_attribs) do
      %i[name requires_kind fixed_start_time fixed_end_time max_lead_days
         max_length_minutes max_days_per_year max_minutes_per_year pre_notice other_communities] <<
        {calendar_ids: [], kinds: []}
    end
    subject { Calendars::ProtocolPolicy.new(actor, protocol).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(*basic_attribs)
    end
  end
end
