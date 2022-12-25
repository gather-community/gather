# frozen_string_literal: true

require "rails_helper"

describe GDrive::SharedDrivePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:communities) { [create(:community), create(:community)] }
    let(:in_user) { create(:user, community: communities[0]) }
    let(:out_user) { create(:user, community: communities[0]) }
    let(:cmty1_admin) { create(:admin, community: communities[0]) }
    let(:cmty2_admin) { create(:admin, community: communities[1]) }
    let(:group) { create(:group, communities: communities, joiners: [in_user]) }
    let(:config) { create(:gdrive_main_config, community: communities[0]) }
    let(:shared_drive) { create(:gdrive_shared_drive, group: group, gdrive_config: config) }
    let(:record) { shared_drive }

    permissions :show? do
      context "with feature flag on" do
        before do
          expect(FeatureFlag).to receive(:lookup).and_return(double(on?: true))
        end

        it "permits users in group" do
          expect(subject).to permit(in_user, record)
        end

        it "permits admins not in group but from shared drive community" do
          expect(subject).to permit(cmty1_admin, record)
        end

        it "forbids admins not in group and not from shared drive community" do
          expect(subject).not_to permit(cmty2_admin, record)
        end

        it "forbids users not in group" do
          expect(subject).not_to permit(out_user, record)
        end
      end

      context "with feature flag off" do
        it "forbids users in group" do
          expect(subject).not_to permit(in_user, record)
        end
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { GDrive::SharedDrive }
    let!(:communities) { [create(:community), create(:community)] }
    let!(:config1) { create(:gdrive_main_config, community: communities[0]) }
    let!(:config2) { create(:gdrive_main_config, community: communities[1]) }
    let!(:group1) { create(:group, communities: [communities[0]], joiners: [actor]) }
    let!(:shared_drive1) { create(:gdrive_shared_drive, group: group1, gdrive_config: config1) }
    let!(:group2) { create(:group, communities: [communities[0]], joiners: []) }
    let!(:shared_drive2) { create(:gdrive_shared_drive, group: group2, gdrive_config: config1) }
    let!(:group3) { create(:group, communities: communities, joiners: [actor]) }
    let!(:shared_drive3) { create(:gdrive_shared_drive, group: group3, gdrive_config: config2) }
    let!(:group4) { create(:group, communities: communities, joiners: []) }
    let!(:shared_drive4) { create(:gdrive_shared_drive, group: group4, gdrive_config: config2) }

    context "with regular user" do
      let(:actor) { create(:user, community: communities[0]) }

      it "returns drives with groups that user is a member of" do
        is_expected.to match_array([shared_drive1, shared_drive3])
      end
    end

    context "with admin" do
      let(:actor) { create(:admin, community: communities[0]) }

      it "returns all drives from user's community plus drives with groups that user is a member of" do
        is_expected.to match_array([shared_drive1, shared_drive2, shared_drive3])
      end
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:shared_drive) { create(:gdrive_shared_drive) }
    let(:actor) { admin }

    subject { described_class.new(actor, GDrive::SharedDrive.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[external_id group_id])
    end
  end
end
