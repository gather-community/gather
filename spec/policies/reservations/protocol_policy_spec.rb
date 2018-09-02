# frozen_string_literal: true

require "rails_helper"

describe Reservations::ProtocolPolicy do
  describe "permissions" do
    include_context "policy objs"
    let(:protocol) { build(:reservation_protocol, community: community) }
    let(:record) { protocol }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins but not regular users"
    end
  end

  describe "scope" do
    let!(:community) { create(:community) }
    let!(:communityB) { create(:community) }
    let!(:protocol1) { create(:reservation_protocol, community: community) }
    let!(:protocol2) { create(:reservation_protocol, community: community) }
    let!(:protocol3) { create(:reservation_protocol, community: communityB) }
    let(:cluster_admin) { create(:cluster_admin, community: community) }
    let(:admin) { create(:admin, community: community) }
    let(:user) { create(:user, community: community) }
    subject(:permitted) { Reservations::ProtocolPolicy::Scope.new(actor, Reservations::Protocol.all).resolve }

    context "for admins, return all protocols in community" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(protocol1, protocol2, protocol3) }
    end

    context "for admins, return all protocols in community" do
      let(:actor) { admin }
      it { is_expected.to contain_exactly(protocol1, protocol2) }
    end

    context "for regular users, return nothing" do
      let(:actor) { user }
      it { is_expected.to be_empty }
    end
  end
end
