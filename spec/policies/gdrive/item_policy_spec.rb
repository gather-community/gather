# frozen_string_literal: true

require "rails_helper"

describe GDrive::ItemPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:communities) { [create(:community), create(:community)] }
    let(:in_user1) { create(:user, community: communities[0]) }
    let(:in_user2) { create(:user, community: communities[0]) }
    let(:out_user) { create(:user, community: communities[0]) }
    let(:cmty1_admin) { create(:admin, community: communities[0]) }
    let(:cmty2_admin) { create(:admin, community: communities[1]) }
    let(:group1) { create(:group, communities: communities, joiners: [in_user1]) }
    let(:group2) { create(:group, communities: communities, joiners: [in_user2]) }
    let(:config) { create(:gdrive_main_config, community: communities[0]) }
    let(:item) { create(:gdrive_item, gdrive_config: config) }
    let!(:item_group1) { create(:gdrive_item_group, item: item, group: group1) }
    let!(:item_group2) { create(:gdrive_item_group, item: item, group: group2) }
    let(:record) { item }

    permissions :show? do
      context "with feature flag on" do
        before do
          expect(FeatureFlag).to receive(:lookup).and_return(double(on?: true))
        end

        context "when item is not missing" do
          it "permits users in group1" do
            expect(subject).to permit(in_user1, record)
          end

          it "permits users in group2" do
            expect(subject).to permit(in_user2, record)
          end

          it "permits admins not in group but from item community" do
            expect(subject).to permit(cmty1_admin, record)
          end

          it "forbids admins not in group and not from item community" do
            expect(subject).not_to permit(cmty2_admin, record)
          end

          it "forbids users not in either group" do
            expect(subject).not_to permit(out_user, record)
          end
        end

        context "when item is missing" do
          before do
            item.missing = true
          end

          it "forbids users in group1" do
            expect(subject).not_to permit(in_user1, record)
          end
        end
      end

      context "with feature flag off" do
        it "forbids users in group" do
          expect(subject).not_to permit(in_user1, record)
        end
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { GDrive::Item }
    let!(:communities) { [create(:community), create(:community)] }
    let!(:config1) { create(:gdrive_main_config, community: communities[0]) }
    let!(:config2) { create(:gdrive_main_config, community: communities[1]) }

    # actor is in this group and it's with communities[0]
    let!(:group1) { create(:group, communities: [communities[0]], joiners: [actor]) }
    let!(:item1) { create(:gdrive_item, gdrive_config: config1) }
    let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group1) }

    # actor is not in this group but it's with communities[0]
    let!(:group2) { create(:group, communities: [communities[0]], joiners: []) }
    let!(:item2) { create(:gdrive_item, gdrive_config: config1) }
    let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group2) }

    # actor is in this group and it's with communities[1]
    let!(:group3) { create(:group, communities: communities, joiners: [actor]) }
    let!(:item3) { create(:gdrive_item, gdrive_config: config2) }
    let!(:item_group3) { create(:gdrive_item_group, item: item3, group: group3) }

    # actor is not in this group and it's with communities[1]
    let!(:group4) { create(:group, communities: communities, joiners: []) }
    let!(:item4) { create(:gdrive_item, gdrive_config: config2) }
    let!(:item_group4) { create(:gdrive_item_group, item: item4, group: group4) }

    # actor is in this group and it's with communities[0], but item is missing
    let!(:group5) { create(:group, communities: [communities[0]], joiners: [actor]) }
    let!(:item5) { create(:gdrive_item, gdrive_config: config1, missing: true) }
    let!(:item_group5) { create(:gdrive_item_group, item: item5, group: group5) }

    context "with regular user" do
      let(:actor) { create(:user, community: communities[0]) }

      it "returns drives with groups that user is a member of" do
        is_expected.to match_array([item1, item3])
      end
    end

    context "with admin" do
      let(:actor) { create(:admin, community: communities[0]) }

      it "returns all drives from user's community plus drives with groups that user is a member of" do
        is_expected.to match_array([item1, item2, item3])
      end
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:item) { create(:gdrive_item) }
    let(:actor) { admin }

    subject { described_class.new(actor, GDrive::Item.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[external_id group_id])
    end
  end
end
