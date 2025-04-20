# frozen_string_literal: true

require "rails_helper"

describe GDrive::ConfigPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:config) { create(:gdrive_config, community: community) }
    let(:record) { config }

    permissions :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins from community"
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { admin }

    subject { described_class.new(actor, GDrive::Config.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[org_user_id client_id client_secret_to_write])
    end
  end
end
