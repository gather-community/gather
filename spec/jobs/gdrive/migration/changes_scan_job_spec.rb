# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ChangesScanJob do
  include_context "jobs"

  let(:community) { Defaults.community }
  let!(:main_config) { create(:gdrive_main_config, org_user_id: "admin@example.org", community: community) }
  let!(:token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id) }
  let!(:migration_config) { create(:gdrive_migration_config, community: community) }
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
      dest_folder_id: "0AExZ3-Cu5q7uUk9PVA")
  end

  # To get latest page token in console:
  # wrapper = GDrive::Wrapper.new(config: GDrive::MainConfig.first, google_user_id: "google.workspace.admin@example.com")
  # wrapper.send(:service).get_changes_start_page_token
  #
  # To get latest changes in console:
  # wrapper.send(:service).list_changes("13326", supports_all_drives: true,
  #   include_items_from_all_drives: true, include_corpus_removals: true, include_removed: true, spaces: "drive",
  #   fields: "changes(fileId,file(id,driveId,name,parents,owners(emailAddress))),nextPageToken")
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
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

  # describe "with changeset containing one new folder" do
  #   let!(:scan_task) { scan.scan_tasks.create!(page_token: "13141") }

  #   it "creates folder map and a copy on dest drive, completes scan, stores new start_page_token" do
  #     VCR.use_cassette("gdrive/migration/scan_job/changes/folder_created") do
  #       expect { perform_job }.not_to have_enqueued_job(described_class)
  #     end

  #     expect(GDrive::Migration::Scan.count).to eq(1)
  #     expect(GDrive::Migration::ScanTask.count).to eq(0)
  #     scan.reload
  #     expect(scan.status).to eq("complete")
  #     expect(GDrive::Migration::FolderMap.find_by(src_id: "1XTSlSd3Bw4dkRN1OTY2lhepebfL_hZBy")).not_to be_nil

  #     operation.reload
  #     expect(operation.start_page_token).to eq("13142")
  #   end
  # end

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

    it "deletes folder map a and c, deletes file c.1, completes scan" do
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

      expect(GDrive::Migration::File.count).to eq(0)
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

    it "deletes folder map a and c, deletes file c.1, completes scan" do
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

      expect(GDrive::Migration::File.count).to eq(0)
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
    # This file will be trashed.
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

      expect(GDrive::Migration::File.count).to eq(0)
    end
  end
end
