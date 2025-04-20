# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::FileDropScanJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Enter the org_user_id for your Google Workspace account below in config.
  # - Create a source folder in a regular Google Drive folder that your org_user_id has access to.
  #   - Paste the ID of that folder as the operation src_folder_id below.
  #   - Create a "Folder A" subfolder that your org_user_id has access to.
  #   - Paste the ID of that folder in the folder_map_a below.
  # - Create a destination Shared Drive for the migration inside your Google Workspace account.
  #   - Paste the ID of that drive as the operation dest_folder_id.
  #   - In that Drive, create the following folder structure:
  #     - Folder A
  #     - Folder B
  #   - Paste the IDs of Folder A and Folder B as the dest ID in the folder maps below
  # - Create a separate Shared Drive to serve as the file drop, leaving it empty.
  #   - Paste the ID of the file drop drive below
  # - Update src and dest folder IDs in the operation below.
  # - Get a fresh Config access_token from the DB after viewing the main GDrive page and add it below.
  #
  # For each real run:
  # - Ensure the folders in the destination Shared Drive are empty
  # - Delete any casettes under spec/cassettes/gdrive/migration/scan_job that you want to adjust.
  #
  # Before committing:
  # - Remove token and real email addresses using global find and replace.

  # Prep function:
  # - Delete everything in source folder and dest folder
  # - Create file tree above

  let(:community) { Defaults.community }
  let!(:config) { create(:gdrive_config, org_user_id: "admin@example.com", community: community) }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: config.org_user_id, access_token: "ya29.a0AeXRPp6h54IVI-JqfIPzHxB7cL-BWsf9bWw3pbP406QUT56AYC3L3RWcENZw-ZJiMjKCGVmbWBXaHpyVfELsBz8_ByqltkIjLG0F2y4RcvX45ICZGxsebjVvfcPSHf8UPb1Zvgld4LRqtzJTBcmFl9MFYoe7dvpA_y42T9wyw78aCgYKAckSARESFQHGX2Mi6UT7JXhV77V2xM21uePB-w0178") }
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, community: community,
      src_folder_id: "1nOK7ou2O9NqiNyJR2bACsitjphr0e6pV",
      dest_folder_id: "0AIQ_OKz_uphLUk9PVA")
  end
  let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "file_drop") }
  let!(:folder_map_a) do
    create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
      src_id: "1M1gPFS7YKXcVyuLaSYIngE7H1augxsAj",
      dest_id: "1OtYkzME_7bUoTjRxyfTurDrAwtsKidM0")
  end
  let!(:folder_map_b) do
    create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
      src_id: "__folder_b_src_id__",
      dest_id: "1YmEQzrLhUOHGkzVkr3ztBfzvYlQ-OPAM")
  end
  let(:file_drop_drive_id) { "0AMPAMmEXmRdFUk9PVA" }

  describe "with multiple files in the drop drive" do
    # Create two files in the file drop drive and paste their IDs below
    let!(:file_a_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1ey5vuhaZLDqO7tPHaEOzpF5bf_BWTD6VHyEf-oTyZc8",
        parent_id: folder_map_a.src_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1FQddhOrRWJxNEyq5m2j9xaKuoKrwyO6s3VsFWKFNUeo",
        parent_id: folder_map_b.src_id)
    end

    it "moves multiple files to the right place" do
      scan_task = scan.scan_tasks.create!(folder_id: file_drop_drive_id)
      VCR.use_cassette("gdrive/migration/scan_job/file_drop/multiple_files") do
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .not_to have_enqueued_job
      end
      expect(file_a_1.reload).to be_transferred
      expect(file_a_1.migrated_parent_id).to eq("1OtYkzME_7bUoTjRxyfTurDrAwtsKidM0")
      expect(file_b_1.reload).to be_transferred
      expect(file_b_1.migrated_parent_id).to eq("1YmEQzrLhUOHGkzVkr3ztBfzvYlQ-OPAM")
      expect(scan.reload).to be_complete
    end
  end

  describe "with a folder in the drop drive" do
    # Create a folder in the drop drive.
    # Then create a file inside that folder drive and paste its ID below.
    let!(:file_a_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1ey5vuhaZLDqO7tPHaEOzpF5bf_BWTD6VHyEf-oTyZc8",
        parent_id: folder_map_a.src_id)
    end

    it "schedules another job, which works" do
      scan_task = scan.scan_tasks.create!(folder_id: file_drop_drive_id)
      VCR.use_cassette("gdrive/migration/scan_job/file_drop/file_in_folder") do
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .to have_enqueued_job(described_class)
        expect(file_a_1.reload).to be_pending
        expect(scan.reload).not_to be_complete

        expect(GDrive::Migration::ScanTask.count).to eq(1)
        new_scan_task = GDrive::Migration::ScanTask.first
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: new_scan_task.id) }
          .not_to have_enqueued_job

        expect(file_a_1.reload).to be_transferred
        expect(scan.reload).to be_complete
      end
    end
  end

  describe "when destination folder doesn't exist" do
    # 1. Create a file in the file drop drive and paste its ID below
    let!(:file_a_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1ey5vuhaZLDqO7tPHaEOzpF5bf_BWTD6VHyEf-oTyZc8",
        parent_id: folder_map_a.src_id)
    end

    before do
      # Update dest ID to nonexistent one
      folder_map_a.update!(dest_id: "1OtYkzME_7bUoTjRxyfTurDrAwtsKixxx")
    end

    it "creates the missing folder from the folder map" do
      scan_task = scan.scan_tasks.create!(folder_id: file_drop_drive_id)
      VCR.use_cassette("gdrive/migration/scan_job/file_drop/dest_not_exist_but_source_does") do
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .not_to have_enqueued_job
      end
      expect(file_a_1.reload).to be_transferred
      expect(scan.reload).to be_complete
    end
  end

  describe "when destination folder and source folder BOTH don't exist" do
    # 1. Create a file in the file drop drive and paste its ID below
    let!(:file_a_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1ey5vuhaZLDqO7tPHaEOzpF5bf_BWTD6VHyEf-oTyZc8",
        parent_id: "kjalfjdlkadlfad")
    end

    before do
      # Update src and dest IDs to nonexistent ones
      folder_map_a.update!(src_id: "kjalfjdlkadlfad", dest_id: "oewiqaoszjdflf")
    end

    it "leaves in drop drive" do
      scan_task = scan.scan_tasks.create!(folder_id: file_drop_drive_id)
      VCR.use_cassette("gdrive/migration/scan_job/file_drop/dest_and_source_not_exist") do
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .not_to have_enqueued_job
      end
      expect(scan.reload).to be_complete
    end
  end

  describe "when file is not recognized" do
    # 1. Create a file in the file drop drive (but we don't create a migration file record)
    it "leaves in drop drive" do
      scan_task = scan.scan_tasks.create!(folder_id: file_drop_drive_id)
      VCR.use_cassette("gdrive/migration/scan_job/file_drop/file_unrecognized") do
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .not_to have_enqueued_job
      end
      expect(scan.reload).to be_complete
    end
  end
end
