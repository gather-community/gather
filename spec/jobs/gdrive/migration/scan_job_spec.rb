# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ScanJob do
  include_context "jobs"

  let!(:main_config) { create(:gdrive_main_config, org_user_id: "drive.admin@gocoho.net") }
  let!(:token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id) }
  let!(:migration_config) { create(:gdrive_migration_config) }
  let!(:operation) do
    create(:gdrive_migration_operation, config: migration_config, dest_folder_id: "0AEFsHNu6aSRGUk9PVA",
      filename_tag: "TS", src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq")
  end
  let!(:scan) { create(:gdrive_migration_scan, operation: operation) }
  let!(:existing_file) do
    # This file already exists and shouldn't get re-tagged or cause unique key collisions.
    create(:gdrive_migration_file, operation: operation, name: "File Root.1",
      external_id: "1dLoyEGGapNBqeZaS5_rNV6tZiq9fbBqNkxgGmJlTVzs")
  end
  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id)
  end

  describe "happy path" do
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: operation.src_folder_id) }

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

      task_count = GDrive::Migration::ScanTask.count
      expect(task_count).to eq(3)
      enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs[-task_count..].map do |j|
        j["arguments"][0]["scan_task_id"]
      end
      expect(enqueued_task_ids).to match_array(GDrive::Migration::ScanTask.all.map(&:id))

      expect(GDrive::Migration::File.all.map(&:name))
        .to contain_exactly("File Root.1", "File Root.2", "Test A", "Test B")

      scan.reload
      expect(scan.scanned_file_count).to eq(4)
      expect(scan.status).to eq("in_progress")
    end
  end

  describe "when encounters unwritable file" do
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV") }

    # We create this one so that the operation doesn't get marked complete, as an extra check on the
    # completeness-marking code.
    let!(:scan_task2) { scan.scan_tasks.create!(folder_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_") }

    it "increments error count" do
      VCR.use_cassette("gdrive/migration/scan_job/single_error") do
        perform_job
      end

      expect { scan_task.reload }.to raise_error(ActiveRecord::RecordNotFound)

      unwritable_file = GDrive::Migration::File.find_by(external_id: "1StDG48lKzbEnlmE5BboPBQCfhSlqxDrReceXiKes1mo")
      expect(unwritable_file.status).to eq("error")
      expect(unwritable_file.error_type).to eq("cant_edit")
      expect(unwritable_file.error_message).to eq("drive.admin@gocoho.net did not have edit permission")

      scan.reload
      expect(scan.error_count).to eq(1)
      expect(scan.status).to eq("in_progress")
    end
  end

  describe "when there are no more scan tasks left" do
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV") }

    it "marks operation complete" do
      VCR.use_cassette("gdrive/migration/scan_job/no_more_tasks") do
        perform_job
      end

      expect(GDrive::Migration::ScanTask.count).to eq(0)
      expect(scan.reload.status).to eq("complete")
    end
  end

  describe "auth error" do
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV") }

    it "cancels operation" do
      VCR.use_cassette("gdrive/migration/scan_job/auth_error") do
        perform_job
      end

      expect { scan_task.reload }.to raise_error(ActiveRecord::RecordNotFound)

      scan.reload
      expect(scan.status).to eq("cancelled")
      expect(scan.cancel_reason).to eq("auth_error")
    end
  end

  describe "when errors reach threshold" do
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV") }

    before do
      stub_const("#{described_class.name}::MIN_ERRORS_TO_CANCEL", 1)
    end

    it "cancels operation" do
      VCR.use_cassette("gdrive/migration/scan_job/error_threshold") do
        perform_job
      end

      expect { scan_task.reload }.to raise_error(ActiveRecord::RecordNotFound)

      scan.reload
      expect(scan.error_count).to eq(1)
      expect(scan.status).to eq("cancelled")
      expect(scan.cancel_reason).to eq("too_many_errors")
    end
  end

  describe "delta scan" do
    let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "delta") }
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: operation.src_folder_id) }

    before do
      stub_const("#{described_class.name}::PAGE_SIZE", 4)
    end

    it "paginates but does not schedule other scans" do
      VCR.use_cassette("gdrive/migration/scan_job/happy_path_delta") do
        expect { perform_job }.to have_enqueued_job(described_class).exactly(1).times
      end

      # Original task should be deleted new task for the next
      # page of the top folder should get added too. But no new folders should get scanned.
      folder_ids = GDrive::Migration::ScanTask.all.map(&:folder_id)
      expect(folder_ids).to contain_exactly("1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq")

      page_tokens = GDrive::Migration::ScanTask.all.map(&:page_token).compact
      expect(page_tokens.size).to eq(1)

      task_count = GDrive::Migration::ScanTask.count
      expect(task_count).to eq(1)
      enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs[-task_count..].map do |j|
        j["arguments"][0]["scan_task_id"]
      end
      expect(enqueued_task_ids).to match_array(GDrive::Migration::ScanTask.all.map(&:id))

      expect(GDrive::Migration::File.all.map(&:name))
        .to contain_exactly("File Root.1", "File Root.2", "Test A", "Test B")

      scan.reload
      expect(scan.scanned_file_count).to eq(4)
      expect(scan.status).to eq("in_progress")
    end
  end
end
