# frozen_string_literal: true

require "rails_helper"

describe GDrive::SyncListener do
  let(:config) { create(:gdrive_main_config) }

  describe "create user" do
    let!(:decoy_group) { create(:group) }
    let!(:decoy_item) { create(:gdrive_item, gdrive_config: config) }
    let!(:decoy_item_group) { create(:gdrive_item_group, item: decoy_item, group: decoy_group) }

    context "with everybody groups that the user automatically joins" do
      let!(:group1) { create(:group, availability: "everybody") }
      let!(:group2) { create(:group, availability: "everybody") }
      let!(:item1) { create(:gdrive_item, gdrive_config: config) }
      let!(:item2) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group1, access_level: "reader") }
      let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group2, access_level: "writer") }

      it "enqueues sync job" do
        expect { create(:user, google_email: "abc@gmail.com") }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("abc@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {item_external_id: item1.external_id, access_level: "reader"},
              {item_external_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end

      it "enqueues nothing if no google_email" do
        expect { create(:user, google_email: nil) }.not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end

    context "with no linked items" do
      it "does not enqueue sync job" do
        expect { create(:user) }.not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end
  end

  describe "update user" do
    let!(:user) { create(:user, google_email: "foo@gmail.com") }
    let!(:group1) { create(:group, joiners: [user]) }
    let!(:item1) { create(:gdrive_item, gdrive_config: config) }
    let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group1, access_level: "reader") }
    let!(:group2) { create(:group, joiners: [user]) }
    let!(:item2) { create(:gdrive_item, gdrive_config: config) }
    let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group2, access_level: "writer") }

    context "when changing google_email" do
      context "from non-nil to non-nil" do
        it "enqueues sync job" do
          expect { user.update!(google_email: "bar@gmail.com") }.to(
            have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
              expect(args.size).to eq(2)
              expect(args[0][:key]).to eq(:google_email)
              expect(args[0][:value]).to eq("foo@gmail.com")
              expect(args[0][:permissions]).to be_empty
              expect(args[1][:key]).to eq(:google_email)
              expect(args[1][:value]).to eq("bar@gmail.com")
              expect(args[1][:permissions]).to contain_exactly(
                {item_external_id: item1.external_id, access_level: "reader"},
                {item_external_id: item2.external_id, access_level: "writer"}
              )
            end
          )
        end
      end

      context "from nil to non-nil" do
        let!(:user) { create(:user, google_email: nil) }

        it "enqueues sync job" do
          expect { user.update!(google_email: "bar@gmail.com") }.to(
            have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
              expect(args.size).to eq(1)
              expect(args[0][:key]).to eq(:google_email)
              expect(args[0][:value]).to eq("bar@gmail.com")
              expect(args[0][:permissions]).to contain_exactly(
                {item_external_id: item1.external_id, access_level: "reader"},
                {item_external_id: item2.external_id, access_level: "writer"}
              )
            end
          )
        end
      end

      context "from non-nil to nil" do
        let!(:user) { create(:user, google_email: "foo@gmail.com") }

        it "enqueues sync job" do
          expect { user.update!(google_email: nil) }.to(
            have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
              expect(args.size).to eq(1)
              expect(args[0][:key]).to eq(:google_email)
              expect(args[0][:value]).to eq("foo@gmail.com")
              expect(args[0][:permissions]).to be_empty
            end
          )
        end
      end
    end

    context "when deactivated" do
      context "if user has google_email" do
        it "enqueues sync job if user has google_email" do
          expect { user.deactivate }.to(
            have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
              expect(args.size).to eq(1)
              expect(args[0][:key]).to eq(:google_email)
              expect(args[0][:value]).to eq("foo@gmail.com")
              expect(args[0][:permissions]).to be_empty
            end
          )
        end
      end

      context "if user has no google email" do
        let!(:user) { create(:user, google_email: nil) }

        it "does not enqueue sync job" do
          expect { user.deactivate }.not_to have_enqueued_job(GDrive::PermissionSyncJob)
        end
      end
    end

    context "when reactivated" do
      let!(:user) { create(:user, :inactive, google_email: "foo@gmail.com") }

      it "enqueues sync job" do
        expect { user.activate }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {item_external_id: item1.external_id, access_level: "reader"},
              {item_external_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end
    end

    context "when removing full_access" do
      it "enqueues sync job" do
        expect { user.update!(child: true, full_access: false, guardians: [create(:user)]) }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to be_empty
          end
        )
      end
    end

    context "when changing to adult" do
      let(:user) { create(:user, :child) }

      it "enqueues sync job" do
        new_attribs = {full_access: true, google_email: "foo@gmail.com", certify_13_or_older: true}
        expect { user.update!(new_attribs) }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {item_external_id: item1.external_id, access_level: "reader"},
              {item_external_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end
    end

    context "when changing to household in different community" do
      let(:community2) { create(:community) }
      let!(:household) { create(:household, community: community2) }

      # The user shouldn't lose access to this item since it's a multi-community group.
      let!(:both_cmty_group) { create(:group, communities: [user.community, community2], joiners: [user]) }
      let!(:item3) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group3) { create(:gdrive_item_group, item: item3, group: both_cmty_group) }

      # The user will get access to this item on the community change since it's an everybody group.
      let!(:other_cmty_ebody_group) { create(:group, communities: [community2], availability: "everybody") }
      let!(:item4) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group4) { create(:gdrive_item_group, item: item4, group: other_cmty_ebody_group) }

      # This item shouldn't get shared since the user isn't a member of the group.
      let!(:other_cmty_decoy_group) { create(:group, communities: [community2]) }
      let!(:item5) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group5) { create(:gdrive_item_group, item: item5, group: other_cmty_decoy_group) }

      it "enqueues sync job" do
        expect { user.update!(household: household) }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {item_external_id: item3.external_id, access_level: "reader"},
              {item_external_id: item4.external_id, access_level: "reader"}
            )
          end
        )
      end
    end

    context "when changing to household in same community" do
      let!(:household) { create(:household) }

      it "does not enqueue sync job" do
        expect { user.update!(household: household) }
          .not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end

    context "when changing other attribute" do
      it "does not enqueue sync job" do
        expect { user.update!(last_name: "Bostich") }
          .not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end
  end

  describe "create group affiliation" do
    let!(:community1) { Defaults.community }
    let!(:community2) { create(:community) }
    let!(:user1) { create(:user, community: community1, google_email: "user1@gmail.com") }
    let!(:user2) { create(:user, community: community2, google_email: "user2@gmail.com") }
    let!(:user3) { create(:user, community: community2, google_email: "user3@gmail.com") }
    let!(:user4) { create(:user, community: community2, google_email: nil) }
    let!(:item1) { create(:gdrive_item, gdrive_config: config, external_id: "abcitem1xyz") }
    let!(:item2) { create(:gdrive_item, gdrive_config: config, external_id: "abcitem2xyz") }

    context "with mapped items" do
      let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group, access_level: "reader") }
      let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group, access_level: "writer") }

      context "when group is an everybody group" do
        let!(:group) { create(:group, communities: [community1], availability: "everybody") }

        it "enqueues sync job" do
          expect { group.communities << community2 }.to(
            have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
              expect(args.size).to eq(2)

              item1_args = args.find { |a| a[:value] == "abcitem1xyz" }
              expect(item1_args[:key]).to eq(:item_external_id)
              expect(item1_args[:value]).to eq("abcitem1xyz")
              expect(item1_args[:permissions]).to contain_exactly(
                {google_email: "user1@gmail.com", access_level: "reader"},
                {google_email: "user2@gmail.com", access_level: "reader"},
                {google_email: "user3@gmail.com", access_level: "reader"}
              )

              item2_args = args.find { |a| a[:value] == "abcitem2xyz" }
              expect(item2_args[:key]).to eq(:item_external_id)
              expect(item2_args[:value]).to eq("abcitem2xyz")
              expect(item2_args[:permissions]).to contain_exactly(
                {google_email: "user1@gmail.com", access_level: "writer"},
                {google_email: "user2@gmail.com", access_level: "writer"},
                {google_email: "user3@gmail.com", access_level: "writer"}
              )
            end
          )
        end
      end

      context "when group is a regular group" do
        let!(:group) { create(:group, communities: [community1]) }

        it "does not enqueue sync job" do
          expect { group.communities << community2 }
            .not_to have_enqueued_job(GDrive::PermissionSyncJob)
        end
      end
    end

    context "without mapped items" do
      context "even if group is an everybody group" do
        let!(:group) { create(:group, communities: [community1], availability: "everybody") }

        it "does not enqueue sync job" do
          expect { group.communities << community2 }
            .not_to have_enqueued_job(GDrive::PermissionSyncJob)
        end
      end
    end
  end
end
