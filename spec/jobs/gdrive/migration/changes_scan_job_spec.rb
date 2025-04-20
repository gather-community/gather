# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ChangesScanJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Create a destination Shared Drive for the migration inside your Google Workspace account.
  # - Under the requestee email, create a source folder/file structure in regular Google Drive as follows:
  #   - Gather Migration Test Source Folder
  # - Share the source folder with your org_user_id.
  # - Update any literal IDs in relevant tests fixtures. The names should make it obvious what ID to get.
  # - Get a fresh main access_token from the DB after viewing the main GDrive page and add it below.
  #
  # For each real run:
  # - Ensure the destination Shared Drive is empty.
  # - Delete any casettes under spec/cassettes/gdrive/migration/scan_job that you want to adjust.

  let(:community) { Defaults.community }
  let!(:config) { create(:gdrive_config, community: community) }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: config.org_user_id, access_token: "ya29.a0AeXRPp6h54IVI-JqfIPzHxB7cL-BWsf9bWw3pbP406QUT56AYC3L3RWcENZw-ZJiMjKCGVmbWBXaHpyVfELsBz8_ByqltkIjLG0F2y4RcvX45ICZGxsebjVvfcPSHf8UPb1Zvgld4LRqtzJTBcmFl9MFYoe7dvpA_y42T9wyw78aCgYKAckSARESFQHGX2Mi6UT7JXhV77V2xM21uePB-w0178") }
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, community: community,
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
      dest_folder_id: "0AExZ3-Cu5q7uUk9PVA")
  end

  # To get latest page token in console:
  # wrapper = GDrive::Wrapper.new(config: GDrive::Config.first, google_user_id: "google.workspace.admin@example.com")
  # wrapper.send(:service).get_changes_start_page_token
  #
  # To get latest changes in console:
  # wrapper.send(:service).list_changes("13326", supports_all_drives: true,
  #   include_items_from_all_drives: true, include_corpus_removals: true, include_removed: true, spaces: "drive",
  #   fields: "changes(fileId,file(id,driveId,name,parents,owners(emailAddress))),nextPageToken")
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, community: community,
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
      dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
      webhook_channel_id: "0009c409-6bf4-473b-ba04-6b0557219502",
      start_page_token: "12683")
  end
  let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "changes") }
  subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

  describe "with changeset containing 3 folders and page size of 2" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "12683") }

    before do
      stub_const("GDrive::Migration::ScanJob::PAGE_SIZE", 2)
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

      operation.reload
      expect(operation.start_page_token).to eq("12683")
    end
  end

  describe "with changeset containing one new folder" do
    # Get the latest start_page_token, then create a new folder in the source drive.
    # Copy the folder's ID below.
    # Copy the start page token below, then add one and copy it further down.
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_registered, community: community,
        src_folder_id: "1F_bPvGfgHj8TEmlTFsZxU69sLB1keEfZ",
        dest_folder_id: "0AIQ_OKz_uphLUk9PVA")
    end
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "41659") }
    let(:new_folder_id) { "1_p9qu3RGOsMi2FJY4Gm_SSXxdvPN78so" }

    it "creates folder map and a copy on dest drive, completes scan, stores new start_page_token" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/folder_created") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")
      expect(GDrive::Migration::FolderMap.find_by(src_id: new_folder_id)).not_to be_nil

      operation.reload
      expect(operation.start_page_token).to eq("41660")
    end
  end

  describe "with changeset containing a change to a mapped folder" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "12738") }
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1fN1rrzq4J28Nv5a0qB2ihbG6bhGs9MjQ", dest_parent_id: operation.dest_folder_id)
    end

    it "updates folder map and copy on dest drive, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/folder_updated") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")
      expect(GDrive::Migration::FolderMap.count).to eq(1)
      folder_map = GDrive::Migration::FolderMap.first
      expect(folder_map.name).to eq("Folder A3")
    end
  end

  describe "with changeset containing a move of a mapped folder to a new parent that is also mapped" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13296") }
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1K9Sq95eB4IUQ_JHrRpNsyNg9PAjvC7Qo", src_parent_id: operation.src_folder_id,
        dest_id: "1J1k3DcfL1kQFmzrnlyiRQvgNs2WNjL-w", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: operation.src_folder_id,
        dest_id: "1v5yAODVs-lL80QtnMHlFRK9CEbFefu9o", dest_parent_id: operation.dest_folder_id)
    end

    # This folder will be moved from A to B
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "15wQB70b0BevG-YLdkMEuhN3tsV9hrV8y", src_parent_id: folder_map_a.src_id,
        dest_id: "1hEcRA06GLBUvvan0unzXJ31Utw6Bk9YN", dest_parent_id: folder_map_a.dest_id)
    end

    it "updates folder map and copy on dest drive, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/folder_moved_to_known_parent") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")
      expect(GDrive::Migration::FolderMap.count).to eq(3)
      folder_map_c = GDrive::Migration::FolderMap.find_by!(name: "Folder C")
      expect(folder_map_c.src_parent_id).to eq(folder_map_b.src_id)
      expect(folder_map_c.dest_parent_id).to eq(folder_map_b.dest_id)
    end
  end

  describe "with changeset containing a move of a mapped folder to a new parent that is not mapped" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13292") }
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1K9Sq95eB4IUQ_JHrRpNsyNg9PAjvC7Qo", src_parent_id: operation.src_folder_id,
        dest_id: "1J1k3DcfL1kQFmzrnlyiRQvgNs2WNjL-w", dest_parent_id: operation.dest_folder_id)
    end

    # This folder will be moved from A to B
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "15wQB70b0BevG-YLdkMEuhN3tsV9hrV8y", src_parent_id: folder_map_a.src_id,
        dest_id: "1hEcRA06GLBUvvan0unzXJ31Utw6Bk9YN", dest_parent_id: folder_map_a.dest_id)
    end

    it "updates folder map c, creates folder map b, moves copy on dest drive, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/folder_moved_to_unknown_parent") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")
      expect(GDrive::Migration::FolderMap.count).to eq(3)

      folder_map_b = GDrive::Migration::FolderMap.find_by!(name: "Folder B")
      expect(folder_map_b.src_id).to eq("1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV")
      expect(folder_map_b.dest_id).to eq("1v5yAODVs-lL80QtnMHlFRK9CEbFefu9o")

      folder_map_c = GDrive::Migration::FolderMap.find_by!(name: "Folder C")
      expect(folder_map_c.src_parent_id).to eq(folder_map_b.src_id)
      expect(folder_map_c.dest_parent_id).to eq(folder_map_b.dest_id)
    end
  end

  describe "with changeset containing a move of a mapped folder to a new parent that is outside tree" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13283") }
    # This folder will be moved outside the tree
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1K9Sq95eB4IUQ_JHrRpNsyNg9PAjvC7Qo", src_parent_id: operation.src_folder_id,
        dest_id: "1J1k3DcfL1kQFmzrnlyiRQvgNs2WNjL-w", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: operation.src_folder_id,
        dest_id: "1v5yAODVs-lL80QtnMHlFRK9CEbFefu9o", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "15wQB70b0BevG-YLdkMEuhN3tsV9hrV8y", src_parent_id: folder_map_a.src_id,
        dest_id: "1hEcRA06GLBUvvan0unzXJ31Utw6Bk9YN", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_c_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1mohxjSbIM_XvHG16aFlBT0yBFxP6sujpCNyOrxUjq1Y",
        parent_id: folder_map_c.src_id)
    end

    it "deletes folder map a and c, updates file c.1 status, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/folder_moved_to_outside_parent") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")

      expect(GDrive::Migration::FolderMap.count).to eq(1)
      folder_map_b = GDrive::Migration::FolderMap.first
      expect(folder_map_b.name).to eq("Folder B")

      expect(GDrive::Migration::File.count).to eq(1)
      expect(file_c_1.reload).to be_disappeared
    end
  end

  describe "with changeset containing a deletion of a folder" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13326") }
    # This folder will be deleted
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1K9Sq95eB4IUQ_JHrRpNsyNg9PAjvC7Qo", src_parent_id: operation.src_folder_id,
        dest_id: "1J1k3DcfL1kQFmzrnlyiRQvgNs2WNjL-w", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: operation.src_folder_id,
        dest_id: "1v5yAODVs-lL80QtnMHlFRK9CEbFefu9o", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "15wQB70b0BevG-YLdkMEuhN3tsV9hrV8y", src_parent_id: folder_map_a.src_id,
        dest_id: "1hEcRA06GLBUvvan0unzXJ31Utw6Bk9YN", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_c_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1mohxjSbIM_XvHG16aFlBT0yBFxP6sujpCNyOrxUjq1Y",
        parent_id: folder_map_c.src_id)
    end

    it "deletes folder map a and c, updates file c.1, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/folder_trashed") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")

      expect(GDrive::Migration::FolderMap.count).to eq(1)
      folder_map_b = GDrive::Migration::FolderMap.first
      expect(folder_map_b.name).to eq("Folder B")

      expect(GDrive::Migration::File.count).to eq(1)
      expect(file_c_1.reload).to be_disappeared
    end
  end

  describe "with changeset containing a new file" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13307") }
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1K9Sq95eB4IUQ_JHrRpNsyNg9PAjvC7Qo", src_parent_id: operation.src_folder_id,
        dest_id: "1J1k3DcfL1kQFmzrnlyiRQvgNs2WNjL-w", dest_parent_id: operation.dest_folder_id)
    end

    it "creates file record, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/file_created") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")

      expect(GDrive::Migration::File.count).to eq(1)
      file_c_2 = GDrive::Migration::File.first
      expect(file_c_2.parent_id).to eq(folder_map_a.src_id)
      expect(file_c_2.name).to eq("File A.2")
    end
  end

  describe "with changeset containing a renamed and moved file" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13304") }
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1K9Sq95eB4IUQ_JHrRpNsyNg9PAjvC7Qo", src_parent_id: operation.src_folder_id,
        dest_id: "1J1k3DcfL1kQFmzrnlyiRQvgNs2WNjL-w", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "15wQB70b0BevG-YLdkMEuhN3tsV9hrV8y", src_parent_id: folder_map_a.src_id,
        dest_id: "1hEcRA06GLBUvvan0unzXJ31Utw6Bk9YN", dest_parent_id: folder_map_a.dest_id)
    end
    # This file will be renamed and moved to Folder A.
    let!(:file_c_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1mohxjSbIM_XvHG16aFlBT0yBFxP6sujpCNyOrxUjq1Y",
        name: "File C.1", parent_id: folder_map_c.src_id)
    end

    it "updates file record, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/file_moved_and_renamed") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")

      file_c_1.reload
      expect(file_c_1.parent_id).to eq(folder_map_a.src_id)
      expect(file_c_1.name).to eq("File C.1 foo")
    end
  end

  describe "with changeset containing a trashed file" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13309") }
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: operation.src_folder_id,
        dest_id: "1v5yAODVs-lL80QtnMHlFRK9CEbFefu9o", dest_parent_id: operation.dest_folder_id)
    end
    # This file will come back from the API as trashed.
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1IufP1TQKUf9ZlU0q-pIdY52Hg5arZc2KYGHqT-dK4nY",
        name: "File B.1", parent_id: folder_map_b.src_id)
    end

    it "removes file record, completes scan" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/file_trashed") do
        expect { perform_job }.not_to have_enqueued_job(described_class)
      end

      expect(GDrive::Migration::Scan.count).to eq(1)
      expect(GDrive::Migration::ScanTask.count).to eq(0)
      scan.reload
      expect(scan.status).to eq("complete")

      expect(GDrive::Migration::File.count).to eq(1)
      expect(file_b_1.reload).to be_disappeared
    end
  end

  describe "with changeset containing multiple files in a file drop drive" do
    let!(:scan_task) { scan.scan_tasks.create!(page_token: "13309") }
    let!(:request) do
      create(:gdrive_migration_request, google_email: "foo@gmail.com",
        operation: operation, file_drop_drive_id: "0AExZ3-Cu5q7uUk9PVX")
    end

    it "enqueues scan job once with appropriate data" do
      VCR.use_cassette("gdrive/migration/scan_job/changes/file_in_drop_drive") do
        expect { perform_job }.to have_enqueued_job(GDrive::Migration::FileDropScanJob)
      end

      # Previous changes scan plus file drop scan
      expect(GDrive::Migration::Scan.count).to eq(2)
      expect(GDrive::Migration::ScanTask.count).to eq(1)
      scan.reload
      expect(scan.status).to eq("complete")

      scan2 = (GDrive::Migration::Scan.all - [scan]).first
      scan2_task = scan2.scan_tasks.first

      expect(scan2.status).to eq("new")
      expect(scan2.scope).to eq("file_drop")
      expect(scan2.log_data).to eq({"request_id" =>  request.id, "request_owner" => "foo@gmail.com"})
    end
  end
end
