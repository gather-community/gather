# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ScanJob do
  include_context "jobs"

  let!(:main_config) { create(:gdrive_main_config, org_user_id: "drive.admin@gocoho.net") }
  let!(:token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id, access_token: "ya29.a0AbVbY6NcC4BtSBJNPImEKwhMKJFpXKW_4jSbotxJ8E49GqWPLbXD2NyTqlwVbJP8pC3yWHE3UfhUIhbOFIMxkXmD_HFYyODpai1A8sEJs3ER8l3Te4MCUR-clHiaP6T054enWkv5zgNozx-wXsSQ0Ptv88LIaCgYKAeASARESFQFWKvPl14ksQIJ63x4y-QHtFV7Myw0163") }
  let!(:migration_config) { create(:gdrive_migration_config) }
  let!(:operation) do
    create(:gdrive_migration_operation, config: migration_config, dest_folder_id: "0AEFsHNu6aSRGUk9PVA",
      filename_tag: "TS", src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq")
  end
  let!(:scan_task) { operation.scan_tasks.create!(folder_id: operation.src_folder_id) }
  let!(:existing_file) do
    # This file already exists and shouldn't get re-tagged or cause unique key collisions.
    create(:gdrive_migration_file, operation: operation, name: "File Root.1",
      external_id: "1dLoyEGGapNBqeZaS5_rNV6tZiq9fbBqNkxgGmJlTVzs")
  end
  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id)
  end

  describe "happy path" do
    before do
      stub_const("#{described_class.name}::PAGE_SIZE", 4)
    end

    it "paginates, tags un-tagged files, creates missing file records, schedules other scans, deletes task" do
      VCR.use_cassette("gdrive/migration/scan_job/happy_path") do
        expect { perform_job }.to have_enqueued_job(described_class).exactly(3).times
      end

      # Original task should be deleted, tasks for sub-folders should get added, and a new task for the next
      # page of the top folder should get added too.
      folder_ids = GDrive::Migration::ScanTask.all.map(&:folder_id)
      expect(folder_ids).to contain_exactly("1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
        "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV")

      page_tokens = GDrive::Migration::ScanTask.all.map(&:page_token).compact
      expect(page_tokens.size).to eq(1)

      enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |j| j["arguments"][0]["scan_task_id"] }
      expect(enqueued_task_ids).to match_array(GDrive::Migration::ScanTask.all.map(&:id))

      expect(GDrive::Migration::File.all.map(&:name))
        .to contain_exactly("File Root.1", "File Root.2", "Test A", "Test B")

      expect(operation.reload.status).to eq("in_progress")
    end
  end
end
