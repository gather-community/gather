# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ScanJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Create a destination Shared Drive for the migration inside your Google Workspace account.
  # - Under the consenter email, create a source folder/file structure in Drive as follows:
  #   - Gather Migration Test Source Folder
  #     - Folder A
  #       - Folder C
  #     - Folder B
  #       - File B.1
  #     - File Root.1
  #     - File Root.2
  #     - File Root.3
  # - Share the source folder with your org_user_id.
  # - Update src and dest folder IDs in the operation below.
  # - Update the existing_file_record external_id below to match Root.1's ID.
  # - Get a fresh main access_token from the DB after viewing the main GDrive page and add it below.
  #
  # For each real run:
  # - Ensure the destination Shared Drive is empty.
  # - Delete any casettes under spec/cassettes/gdrive/migration/scan_job that you want to adjust.
  #
  # Before committing:
  # - Remove token and real email addresses using global find and replace.

  let!(:main_config) { create(:gdrive_main_config, org_user_id: "admin@example.org") }
  let!(:token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id, access_token: "ya29.a0AfB_byBRJRSsYLU-cI8Pw6zBGiaWa80EvNT3qod5hwwfs-AwkyLvamq0LwA-SJO_IQQHOZJPpq15-VNKk5TQj8LIM0ig26Fja1FcyL_XEDEJ_K20iyEzLOs16AHDNqQhTrhOXMwZxkkuNpokRAkIr2LRJMeb5fwvGG4MeKMaCgYKAXESARESFQHGX2MiXuTVMS8n3nCznNFLOEXxkg0174") }
  let!(:migration_config) { create(:gdrive_migration_config) }
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
      dest_folder_id: "0AExZ3-Cu5q7uUk9PVA")
  end

  describe "full scan" do
    let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "full") }

    describe "first run" do
      let!(:operation) do
        create(:gdrive_migration_operation, :webhook_not_registered, config: migration_config,
          src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
          dest_folder_id: "0AExZ3-Cu5q7uUk9PVA")
      end
      let!(:existing_file_record) do
        # This file already exists and shouldn't cause unique key collisions.
        create(:gdrive_migration_file, operation: operation, name: "File Root.1",
          parent_id: operation.src_folder_id,
          external_id: "1wALtADTYpUwEgeenScUMGghzPMIYXuDnP4Orv-alKno")
      end
      let(:folder_a_id) { "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_" }
      let(:folder_b_id) { "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV" }

      before do
        stub_const("#{described_class.name}::PAGE_SIZE", 4)
      end

      it "paginates, tags un-tagged files, creates missing file records, creates folders, schedules other scans, deletes task" do
        VCR.use_cassette("gdrive/migration/scan_job/full/first_run") do
          scan_task = scan.scan_tasks.create!(folder_id: operation.src_folder_id)
          expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
            .to have_enqueued_job(described_class).exactly(3).times

          # Original task should be deleted, tasks for sub-folders should get added, and a new task for the next
          # page of the top folder should get added too.
          folder_ids = GDrive::Migration::ScanTask.all.map(&:folder_id)
          expect(folder_ids).to contain_exactly(operation.src_folder_id,
            folder_a_id, folder_b_id)

          expect(GDrive::Migration::FolderMap.count).to eq(2)

          page_tokens = GDrive::Migration::ScanTask.all.map(&:page_token).compact
          expect(page_tokens.size).to eq(1)

          task_count = GDrive::Migration::ScanTask.count
          expect(task_count).to eq(3)
          enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs[-task_count..].map do |j|
            j["arguments"][0]["scan_task_id"]
          end
          expect(enqueued_task_ids).to match_array(GDrive::Migration::ScanTask.all.map(&:id))

          expect(GDrive::Migration::File.all.map(&:name))
            .to contain_exactly("File Root.1", "File Root.2")

          scan.reload
          expect(scan.scanned_file_count).to eq(4)
          expect(scan.status).to eq("in_progress")

          scan_task = scan.scan_tasks.create!(folder_id: folder_a_id)
          expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
            .to have_enqueued_job(described_class).once
        end
      end
    end

    describe "when there are no more scan tasks left" do
      let!(:operation) do
        create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
          src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
          dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
          webhook_channel_id: "b0801a4c-4437-4284-b723-035c7c7f87f8",
          start_page_token: "12345")
      end
      let(:folder_b_id) { "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV" }
      let!(:scan_task) { scan.scan_tasks.create!(folder_id: folder_b_id) }
      subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

      it "marks operation complete and registers webhook" do
        VCR.use_cassette("gdrive/migration/scan_job/full/no_more_tasks") do
          expect { perform_job }.to have_enqueued_job(described_class)
        end

        expect(scan.reload.status).to eq("complete")
        expect(GDrive::Migration::Scan.count).to eq(2)
        expect(GDrive::Migration::ScanTask.count).to eq(1)
        scan_task = GDrive::Migration::ScanTask.first
        expect(scan_task.page_token).to eq("12345")
        expect(scan_task.scan.scope).to eq("changes")
      end
    end

    describe "auth error" do
      let(:folder_b_id) { "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV" }
      let!(:scan_task) { scan.scan_tasks.create!(folder_id: folder_b_id) }
      subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

      it "cancels operation" do
        VCR.use_cassette("gdrive/migration/scan_job/full/auth_error") do
          perform_job
        end

        expect { scan_task.reload }.to raise_error(ActiveRecord::RecordNotFound)

        scan.reload
        expect(scan.status).to eq("cancelled")
        expect(scan.cancel_reason).to eq("auth_error")
      end
    end

    describe "scan task disappears" do
      let!(:scan_task) { scan.scan_tasks.create!(folder_id: operation.src_folder_id) }
      subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

      before do
        scan_task.destroy
      end

      it "terminates gracefully and makes no network calls" do
        perform_job
      end
    end
  end

  describe "changes scan" do
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
        src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
        dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
        webhook_channel_id: "0009c409-6bf4-473b-ba04-6b0557219502")
    end
    let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "changes") }
    subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

    describe "with changeset containing 3 folders and page size of 2" do
      let!(:scan_task) { scan.scan_tasks.create!(page_token: "12683") }

      before do
        stub_const("#{described_class.name}::PAGE_SIZE", 2)
      end

      it "paginates but does not schedule other folder scans" do
        VCR.use_cassette("gdrive/migration/scan_job/changes/pagination") do
          expect { perform_job }.to have_enqueued_job(described_class).exactly(1).times
        end

        # Original task should be deleted new and task for the next
        # page of the changes should get added too. But no new folders should get scanned.
        scan_tasks = GDrive::Migration::ScanTask.all
        expect(scan_tasks.size).to eq(1)
        expect(scan_tasks[0].folder_id).to be_nil
        expect(scan_tasks[0].page_token).not_to be_nil
        enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs[-scan_tasks.size..].map do |j|
          j["arguments"][0]["scan_task_id"]
        end
        expect(enqueued_task_ids).to eq([scan_tasks[0].id])

        scan.reload
        expect(scan.status).to eq("in_progress")
      end
    end
  end
end
