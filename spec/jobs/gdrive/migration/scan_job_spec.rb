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
  #         - File C.1
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

  # Prep function:
  # - Delete everything in source folder and dest folder
  # - Create file tree above

  let(:community) { Defaults.community }
  let!(:main_config) { create(:gdrive_main_config, org_user_id: "admin@example.org", community: community) }
  let!(:token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id) }
  let!(:migration_config) { create(:gdrive_migration_config, community: community) }
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
                                                             src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
                                                             dest_folder_id: "0AExZ3-Cu5q7uUk9PVA")
  end

  describe "full scan" do
    let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "full") }

    # describe "first run" do
    #   let!(:operation) do
    #     create(:gdrive_migration_operation, :webhook_not_registered, config: migration_config,
    #       src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
    #       dest_folder_id: "0AExZ3-Cu5q7uUk9PVA")
    #   end
    #   let!(:existing_file_record) do
    #     # This file already exists and shouldn't cause unique key collisions.
    #     create(:gdrive_migration_file, operation: operation, name: "File Root.1",
    #       parent_id: operation.src_folder_id,
    #       external_id: "1wALtADTYpUwEgeenScUMGghzPMIYXuDnP4Orv-alKno")
    #   end
    #   let(:folder_a_id) { "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_" }
    #   let(:folder_b_id) { "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV" }

    #   before do
    #     stub_const("#{described_class.name}::PAGE_SIZE", 4)
    #   end

    #   it "paginates, tags un-tagged files, creates missing file records, creates folders,
    #         saves token, schedules other scans, deletes task" do
    #     VCR.use_cassette("gdrive/migration/scan_job/full/first_run") do
    #       scan_task = scan.scan_tasks.create!(folder_id: operation.src_folder_id)
    #       expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
    #         .to have_enqueued_job(described_class).exactly(3).times

    #       # Original task should be deleted, tasks for sub-folders should get added, and a new task for the next
    #       # page of the top folder should get added too.
    #       folder_ids = GDrive::Migration::ScanTask.all.map(&:folder_id)
    #       expect(folder_ids).to contain_exactly(operation.src_folder_id,
    #         folder_a_id, folder_b_id)

    #       expect(GDrive::Migration::FolderMap.count).to eq(2)

    #       page_tokens = GDrive::Migration::ScanTask.all.map(&:page_token).compact
    #       expect(page_tokens.size).to eq(1)

    #       task_count = GDrive::Migration::ScanTask.count
    #       expect(task_count).to eq(3)
    #       enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs[-task_count..].map do |j|
    #         j["arguments"][0]["scan_task_id"]
    #       end
    #       expect(enqueued_task_ids).to match_array(GDrive::Migration::ScanTask.all.map(&:id))

    #       expect(GDrive::Migration::File.all.map(&:name))
    #         .to contain_exactly("File Root.1", "File Root.2")

    #       operation.reload
    #       expect(operation.start_page_token).to eq("12676")
    #       expect(operation.webhook_channel_id).not_to be_nil
    #       expect(operation.webhook_secret).not_to be_nil
    #       expect(operation.webhook_resource_id).to be_nil
    #       expect(operation.webhook_expires_at).to be_nil

    #       scan.reload
    #       expect(scan.scanned_file_count).to eq(4)
    #       expect(scan.status).to eq("in_progress")

    #       scan_task = scan.scan_tasks.create!(folder_id: folder_a_id)
    #       expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
    #         .to have_enqueued_job(described_class).once
    #     end
    #   end
    # end

    describe "when there are no more scan tasks left" do
      let(:community) { create(:community, id: 123) }
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
        time = Time.zone.parse("2024-01-10 12:00:00")
        Timecop.freeze(time) do
          VCR.use_cassette("gdrive/migration/scan_job/full/no_more_tasks") do
            expect { perform_job }.to have_enqueued_job(described_class)
          end

          expect(scan.reload.status).to eq("complete")
          expect(GDrive::Migration::Scan.count).to eq(2)
          expect(GDrive::Migration::ScanTask.count).to eq(1)
          scan_task = GDrive::Migration::ScanTask.first
          expect(scan_task.page_token).to eq("12345")
          expect(scan_task.scan.scope).to eq("changes")

          operation.reload
          expect(operation.start_page_token).to eq("12345")
          expect(operation.webhook_channel_id).not_to be_nil
          expect(operation.webhook_secret).not_to be_nil
          expect(operation.webhook_resource_id).to eq("030dP89w23Mzw28mQBrIu00iMXg")
          expect(operation.webhook_expires_at).to eq(time + 7.days)
        end
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
end
