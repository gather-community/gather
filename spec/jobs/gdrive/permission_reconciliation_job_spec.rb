# frozen_string_literal: true

require "rails_helper"

describe GDrive::PermissionReconciliationJob do
  include_context "jobs"

  let!(:config) { create(:gdrive_config, org_user_id: "drive.admin@example.com") }
  let!(:item1) { create(:gdrive_item, gdrive_config: config, external_id: "item1") }
  let!(:item2) { create(:gdrive_item, gdrive_config: config, external_id: "item2") }
  let!(:inaccessible) do
    create(:gdrive_item, gdrive_config: config, external_id: "item3", error_type: "inaccessible")
  end
  let(:discrepancy) do
    GDrive::PermissionAudit::Discrepancy.new(kind: :excess_access, user_id: 123, expected_level: nil,
      actual_level: "writer")
  end
  let(:synced_item_ids) { [] }

  before do
    synced = synced_item_ids
    allow_any_instance_of(GDrive::ItemPermissionSyncJob).to receive(:perform) do |_job, **args|
      synced << args[:item_id]
      expect(args[:refresh_synced_permissions]).to be(true)
    end
    allow_any_instance_of(GDrive::PermissionAudit).to receive(:discrepancies) do |audit|
      (audit.item.id == item1.id) ? [discrepancy] : []
    end
  end

  context "when the community is connected" do
    let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "drive.admin@example.com") }

    it "syncs each accessible item and reports the ones that still differ" do
      expect(Gather::ErrorReporter.instance).to receive(:report).once do |error, data:|
        expect(error).to be_a(described_class::DiscrepancyError)
        expect(data).to include(community_id: config.community_id, item_id: item1.id, discrepancy_count: 1,
          discrepancies: [discrepancy.to_h])
      end

      perform_job

      expect(synced_item_ids).to eq([item1.id, item2.id])
    end

    context "when an item's sync fails" do
      before do
        allow_any_instance_of(GDrive::ItemPermissionSyncJob).to receive(:perform) do |_job, **args|
          synced_item_ids << args[:item_id]
          raise WithAdvisoryLock::FailedToAcquireLock, "lock" if args[:item_id] == item1.id
        end
      end

      it "reports it, still audits that item, and carries on" do
        reported = []
        allow(Gather::ErrorReporter.instance).to receive(:report) { |error, **| reported << error.class }

        perform_job

        expect(synced_item_ids).to eq([item1.id, item2.id])
        expect(reported).to eq([WithAdvisoryLock::FailedToAcquireLock, described_class::DiscrepancyError])
      end
    end
  end

  context "when the community isn't connected" do
    it "does nothing" do
      expect(Gather::ErrorReporter.instance).not_to receive(:report)
      perform_job
      expect(synced_item_ids).to be_empty
    end
  end
end
