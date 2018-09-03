# frozen_string_literal: true

require "rails_helper"

describe Reservations::ProtocolPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:protocol) { build(:reservation_protocol, community: community) }
    let(:record) { protocol }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins but not regular users"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Reservations::Protocol }
    let!(:objs_in_community) { create_list(:reservation_protocol, 2, community: community) }
    let!(:objs_in_cluster) { create_list(:reservation_protocol, 2, community: communityB) }

    it_behaves_like "allows only admins in community"
  end
end
