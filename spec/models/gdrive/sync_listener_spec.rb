# frozen_string_literal: true

require "rails_helper"

describe GDrive::SyncListener do
  context "with gdrive config" do
    let!(:config) { create(:gdrive_config) }
    let!(:community) { Defaults.community }

    describe "create user" do
      let!(:decoy_group) { create(:group) }
      let!(:decoy_item) { create(:gdrive_item, gdrive_config: config) }
      let!(:decoy_item_group) { create(:gdrive_item_group, item: decoy_item, group: decoy_group) }

      context "with everybody group that the user automatically joins" do
        let!(:group) { create(:group, availability: "everybody") }
        let!(:item) { create(:gdrive_item, gdrive_config: config) }
        let!(:item_group) { create(:gdrive_item_group, item: item, group: group, access_level: "reader") }

        it "enqueues sync job" do
          expect_enqueues_job_with_users(User.new) { create(:user, google_email: "abc@gmail.com") }
        end

        it "enqueues nothing if no google_email" do
          expect_doesnt_enqueue_job { create(:user, google_email: nil) }
        end
      end

      context "with no linked items" do
        it "does not enqueue sync job" do
          expect_doesnt_enqueue_job { create(:user) }
        end
      end
    end

    describe "update user" do
      let!(:user) { create(:user, google_email: "foo@gmail.com") }

      context "when changing google_email" do
        context "from non-nil to non-nil" do
          it "enqueues sync job" do
            expect_enqueues_job_with_users(user) { user.update!(google_email: "bar@gmail.com") }
          end
        end

        context "from nil to non-nil" do
          let!(:user) { create(:user, google_email: nil) }

          it "enqueues sync job" do
            expect_enqueues_job_with_users(user) { user.update!(google_email: "bar@gmail.com") }
          end
        end

        context "from non-nil to nil" do
          let!(:user) { create(:user, google_email: "foo@gmail.com") }

          it "enqueues sync job" do
            expect_enqueues_job_with_users(user) { user.update!(google_email: nil) }
          end
        end
      end

      context "when deactivated" do
        context "if user has google_email" do
          it "enqueues sync job" do
            expect_enqueues_job_with_users(user) { user.deactivate }
          end
        end

        context "if user has no google email" do
          let!(:user) { create(:user, google_email: nil) }

          it "does not enqueue sync job" do
            expect_doesnt_enqueue_job { user.deactivate }
          end
        end
      end

      context "when reactivated" do
        let!(:user) { create(:user, :inactive, google_email: "foo@gmail.com") }

        it "enqueues sync job" do
          expect_enqueues_job_with_users(user) { user.activate }
        end
      end

      context "when removing full_access" do
        it "enqueues sync job" do
          expect_enqueues_job_with_users(user) do
            user.update!(child: true, full_access: false, guardians: [create(:user)])
          end
        end
      end

      context "when changing to adult" do
        let(:user) { create(:user, :child) }

        it "enqueues sync job" do
          new_attribs = {full_access: true, google_email: "foo@gmail.com", certify_13_or_older: true}
          expect_enqueues_job_with_users(user) { user.update!(new_attribs) }
        end
      end

      context "when changing to household in different community" do
        let!(:community2) { create(:community) }
        let!(:config2) { create(:gdrive_config, community: community2) }
        let!(:household) { create(:household, community: community2) }

        it "enqueues sync job" do
          expect_enqueues_job_with_users(user, communities: [community, community2]) do
            user.update!(household: household)
          end
        end
      end

      context "when changing to household in same community" do
        let!(:household) { create(:household) }

        it "does not enqueue sync job" do
          expect_doesnt_enqueue_job { user.update!(household: household) }
        end
      end

      context "when changing other attribute" do
        it "does not enqueue sync job" do
          expect_doesnt_enqueue_job { user.update!(last_name: "Bostich") }
        end
      end
    end

    describe "destroy user" do
      let!(:user) { create(:user, google_email: "foo@gmail.com") }

      context "if user has google_email" do
        it "enqueues sync job" do
          expect_enqueues_job_with_users(user) { user.destroy }
        end
      end

      context "if user has no google email" do
        let!(:user) { create(:user, google_email: nil) }

        it "does not enqueue sync job" do
          expect_doesnt_enqueue_job { user.destroy }
        end
      end
    end

    describe "update household" do
      let!(:household) { create(:household, member_count: 2) }
      let!(:community2) { create(:community) }
      let!(:config2) { create(:gdrive_config, community: community2) }

      context "with community change" do
        it "enqueues job for each user" do
          expect_enqueues_job_with_users(*household.users[0..1], communities: [community, community2]) do
            household.update!(community: community2)
          end
        end
      end

      context "without community change" do
        it "does not enqueue sync job" do
          expect_doesnt_enqueue_job { household.update!(name: "Corpthwaite") }
        end
      end
    end

    describe "item group" do
      let!(:item) { create(:gdrive_item, gdrive_config: config) }

      describe "create item group" do
        it "enqueues sync job" do
          expect_enqueues_job_with_items(item) { create(:gdrive_item_group, item: item) }
        end
      end

      describe "update item group" do
        let!(:item_group) { create(:gdrive_item_group, item: item, access_level: "reader") }

        it "enqueues sync job" do
          expect_enqueues_job_with_items(item) { item_group.update!(access_level: "writer") }
        end
      end

      describe "destroy item/item group" do
        let!(:item_group) { create(:gdrive_item_group, item: item, access_level: "reader") }

        it "enqueues sync job" do
          expect_enqueues_job_with_items(item) { item.destroy }
        end
      end
    end

    describe "group membership" do
      let!(:group) { create(:group) }
      let!(:item1) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group1) { create(:gdrive_item_group, group: group, item: item1) }
      let!(:item2) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group2) { create(:gdrive_item_group, group: group, item: item2) }
      let!(:decoy) { create(:gdrive_item, gdrive_config: config) }

      describe "create group membership" do
        it "enqueues sync job" do
          expect_enqueues_job_with_items(item1, item2) { create(:group_membership, group: group) }
        end
      end

      describe "update group membership" do
        let!(:membership) { create(:group_membership, group: group) }

        it "enqueues sync job" do
          expect_enqueues_job_with_items(item1, item2) { membership.update!(kind: "manager") }
        end
      end

      describe "destroy membership" do
        let!(:membership) { create(:group_membership, group: group) }

        it "enqueues sync job" do
          expect_enqueues_job_with_items(item1, item2) { membership.destroy }
        end
      end

      describe "destroy group and membership at once" do
        let!(:membership) { create(:group_membership, group: group) }

        it "enqueues sync job" do
          expect_enqueues_job_with_items(item1, item2) { group.destroy }
        end
      end
    end

    describe "update group" do
      let!(:group) { create(:group) }
      let!(:item1) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group1) { create(:gdrive_item_group, group: group, item: item1) }
      let!(:item2) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group2) { create(:gdrive_item_group, group: group, item: item2) }
      let!(:decoy) { create(:gdrive_item, gdrive_config: config) }

      it "enqueues sync job if availability changes" do
        expect_enqueues_job_with_items(item1, item2) { group.update!(availability: "everybody") }
      end

      it "enqueues sync job if deactivated/reactivated" do
        expect_enqueues_job_with_items(item1, item2) { group.deactivate }
        expect_enqueues_job_with_items(item1, item2) { group.activate }
      end

      it "does not enqueue if availability/deactivated_at don't change" do
        expect_doesnt_enqueue_job { group.update!(name: "Foo") }
      end
    end

    describe "create group affiliation" do
      let!(:community2) { create(:community) }
      let!(:item1) { create(:gdrive_item, gdrive_config: config) }
      let!(:item2) { create(:gdrive_item, gdrive_config: config) }

      context "with mapped items" do
        let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group, access_level: "reader") }
        let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group, access_level: "writer") }

        context "when group is an everybody group" do
          let!(:group) { create(:group, communities: [community], availability: "everybody") }

          it "enqueues sync job" do
            expect_enqueues_job_with_items(item1, item2) do
              group.communities << community2
            end
          end
        end

        context "when group is a regular group" do
          let!(:group) { create(:group, communities: [community]) }

          it "does not enqueue sync job" do
            expect_doesnt_enqueue_job { group.communities << community2 }
          end
        end
      end

      context "without mapped items" do
        let!(:group) { create(:group, communities: [community], availability: "everybody") }

        it "does not enqueue sync job" do
          expect_doesnt_enqueue_job { group.communities << community2 }
        end
      end
    end
  end

  context "without gdrive config" do
    describe "update user" do
      let!(:user) { create(:user, google_email: "foo@gmail.com") }

      it "does not enqueue sync job" do
        expect_doesnt_enqueue_job { user.update!(google_email: "bar@gmail.com") }
      end
    end

    describe "destroy user" do
      let!(:user) { create(:user, google_email: "foo@gmail.com") }

      it "does not enqueue sync job" do
        expect_doesnt_enqueue_job { user.destroy }
      end
    end
  end

  def expect_enqueues_job_with_users(*users, communities: [Defaults.community], &block)
    expect_enqueues_job_with_objects(users, job_class: GDrive::UserPermissionSyncJob,
      id_key: :user_id, communities: communities, &block)
  end

  def expect_enqueues_job_with_items(*items, &block)
    expect_enqueues_job_with_objects(items, job_class: GDrive::ItemPermissionSyncJob,
      id_key: :item_id, communities: [items[0].community], &block)
  end

  def expect_enqueues_job_with_objects(objects, job_class:, id_key:, communities:, &block)
    calls = []
    expect(&block).to have_enqueued_job(job_class).exactly(objects.size * communities.size).times
      .with { |**args| calls << args }
    expected_params = objects.flat_map do |obj|
      communities.map do |community|
        expected_id = obj.persisted? ? obj.id : anything
        {:cluster_id => Defaults.cluster.id, :community_id => community.id, id_key => expected_id}
      end
    end
    expect(calls).to match_array(expected_params)
  end

  def expect_doesnt_enqueue_job(&block)
    expect_example = expect(&block)
    expect_example.to have_not_enqueued_job(GDrive::UserPermissionSyncJob).and(
      have_not_enqueued_job(GDrive::ItemPermissionSyncJob)
    )
  end
end
