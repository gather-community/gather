# frozen_string_literal: true

require "rails_helper"

describe GDrive::SyncListener do
  describe "create user" do
    let(:config) { create(:gdrive_main_config) }
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

      it "enqueues sync job with correct params" do
        expect { create(:user, google_email: "abc@gmail.com") }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with(array_including(
            [
              {google_email: "abc@gmail.com", item_id: item1.external_id, access_level: "reader"},
              {google_email: "abc@gmail.com", item_id: item2.external_id, access_level: "writer"}
            ]
          ))
        )
      end
    end

    context "with no linked items" do
      it "doesn't enqueue job" do
        expect { create(:user) }.not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end
  end
end
