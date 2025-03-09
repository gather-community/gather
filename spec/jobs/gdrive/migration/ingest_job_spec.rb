# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::IngestJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Set a valid requestee email (regular Google account) and org_user_id (Google Workspace account).
  # - Under the requestee email, create a source folder/file structure in regular Drive as follows:
  #   - Gather Migration Test Source Folder
  #     - Folder A
  #       - Folder B
  #         - File B.1
  #       - Folder C
  #         - File C.1
  #     - File Root.1
  # - Share the source folder with your org_user_id.
  # - Create a destination Shared Drive for the migration inside your Google Workspace account.
  # - In the Shared Drive, create the following folder structure (no files).
  #   - Folder A
  #     - Folder B
  #     - Folder C
  # - Update src and dest folder IDs in the Operation below.
  # - Update the src_ids and dest_ids in the folder maps below.
  # - Get a fresh main access_token from the DB after viewing the main GDrive page and add it below.
  # - Create a Request in dev mode under the requestee email and load the pick page.
  # - Get a fresh migration access_token from the DB after viewing the pick page and add it below.
  # - Make sure delayed job isn't running so your files don't get processed in dev mode when you pick them.
  #
  # For each real run:
  # - Ensure the destination Shared Drive folders have no files.
  # - Delete all migration temp drives.
  # - If files got moved:
  #   - Create new File B.1, C.1, Root.1.
  #   - Update the external_ids in the file records below to match the new files.
  #   - Delete the old Request and make a new one
  #      - GDrive::Migration::Request.create(google_email: "x@y.com", operation: GDrive::Migration::Operation.last, file_count: 10)
  #   - Pick files B.1, C.1, and Root.1 using the Google Picker in the request process.
  # - Delete any casettes under spec/cassettes/gdrive/migration/ingest_job that you want to adjust.
  # - Update the request_id to a new random UUID (SecureRandom.uuid)
  # - Take any manual steps described in the test, like deleting Drive folders.
  #
  # Before committing:
  # - Remove tokens and real email addresses using global find and replace.

  let(:requestee_email) { "example@gmail.com" }
  let!(:main_config) { create(:gdrive_main_config) }
  let!(:main_token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id) }
  let!(:migration_config) { create(:gdrive_migration_config) }
  let!(:migration_token) { create(:gdrive_token, gdrive_config: migration_config, google_user_id: requestee_email) }
  let!(:operation) do
    create(:gdrive_migration_operation, config: migration_config, dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq")
  end
  let!(:request) do
    # We need a known ID value or it may not match what's in the cassette.
    create(:gdrive_migration_request, id: 537716653, operation: operation,
      google_email: requestee_email, file_count: 3)
  end

  before do
    allow(described_class).to receive(:random_request_id).and_return(request_id)

    # For the first run, set file_b_1 to be ingested, which will create folders B and A
    request.setup_ingest([file_b_1.external_id])
  end

  describe "happy path" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1fGgtI-ynyMIzi7Tp2d8bwY542jrbmAnz", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "1yWXMPJnSpso__yXpopV_WZ-kBj39GJi-", src_parent_id: folder_map_a.src_id,
        dest_id: "14huMaHzvNxvfxdoQPqm3fLVOT0I1oDk-", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "11jdjwgwY0duK5kMMb8b97tuvCH8TC_aDtXvAXs7N2tU",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let!(:file_c_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1obo1kO6zdxnBZE9DpCfjSQk9-tVUp8u_QKR9XtzmsSI",
        parent_id: folder_map_c.src_id, owner: requestee_email)
    end
    let!(:file_root_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1TYsGVe0Vro-wCIMG_sk4aIiko5PPM8N0c8KwN1eXkMY",
        parent_id: operation.src_folder_id, owner: requestee_email)
    end
    let(:request_id) { "51e86502-b047-4c06-9a7c-e9fa35137858" }

    it "creates temp drive, creates and reuses parent folders, double-moves files, updates statuses" do
      VCR.use_cassette("gdrive/migration/ingest_job/happy_path") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        request.reload

        expect(request).to be_ingest_done
        expect(request.ingest_progress).to eq(1)
        expect(request).to be_in_progress

        # We ingested one file so there should be 3 - 1 = 2 left now
        expect(request.file_count).to eq(2)
        file_b_1.reload
        expect(file_b_1).to be_transferred
        file_c_1.reload
        expect(file_c_1).to be_pending

        # Second time, ingest:
        # - file_c_1, which creates folder C and reuses folder A
        # - file_root_1, which demonstrates multiple ingestions per job
        #
        # These are also the last files for the requestee so we should mark the request done.
        request.setup_ingest([file_c_1.external_id, file_root_1.external_id])
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)

        request.reload
        expect(request).to be_ingest_done
        expect(request.ingest_progress).to eq(2)
        expect(request).to be_done
        expect(request.file_count).to eq(0)
        file_c_1.reload
        expect(file_c_1).to be_transferred
        file_root_1.reload
        expect(file_root_1).to be_transferred
      end
    end
  end

  describe "source folder with no folder map but dest folder does exist" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1wX5bKq7TPUHS2tX0UM9SJkAEhGsJy-H3", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1CLjCdL5-73nj5aybzafYyucgGpI9kFfaKR5TB8QLtOs",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let(:request_id) { "3829126f-6917-44ea-af36-9b26e3e2c164" }

    before do
      folder_map_b.destroy
    end

    it "should find and use the dest folder" do
      VCR.use_cassette("gdrive/migration/ingest_job/no_folder_map_but_folder_exists") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_transferred
        GDrive::Migration::FolderMap.find_by!(name: "Folder B", src_id: file_b_1.parent_id)
      end
    end
  end

  # Before running this spec, ensure that Folder B does NOT exist in the shared drive
  describe "source folder with no folder map and dest folder doesn't exist" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1fGgtI-ynyMIzi7Tp2d8bwY542jrbmAnz", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1hfyPrCWbphUSqoYvPE1DxLkJmV77AzpO6A0f_IyiLzs",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let(:request_id) { "639a0455-60a6-4634-8dfc-9f016d6bd450" }

    before do
      folder_map_b.destroy
    end

    it "should create the dest folder" do
      VCR.use_cassette("gdrive/migration/ingest_job/no_folder_map_and_no_folder") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_transferred
        GDrive::Migration::FolderMap.find_by!(name: "Folder B", src_id: file_b_1.parent_id)
      end
    end
  end

  # Before running this spec, move source Folder B to some other folder in your My Drive
  # and ensure the folder is still shared with the workspace user.
  describe "source folder with no folder map and not in the migration tree" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1bGXLuClPL7w0GFB_rAga0duf5tFxkTIh_vZFbrOfW5U",
        parent_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", owner: requestee_email)
    end
    let(:request_id) { "bbbcc008-8209-4078-ba44-be50f6a668f1" }

    it "should fail gracefully and store error message" do
      VCR.use_cassette("gdrive/migration/ingest_job/no_folder_map_and_outside_tree") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_errored
        expect(file_b_1.error_type).to eq("ancestor_inaccessible")
        expect(file_b_1.error_message).to eq("Parent of folder #{file_b_1.parent_id} is inaccessible")
        expect(request.reload.ingest_progress).to eq(1)
        expect(request.error_count).to eq(1)
      end
    end
  end

  # Before running this spec, move source Folder B to some other folder in your My Drive
  # and ensure the folder is still shared with the workspace user.
  describe "with max errors" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1bGXLuClPL7w0GFB_rAga0duf5tFxkTIh_vZFbrOfW5U",
        parent_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", owner: requestee_email)
    end
    let!(:file_b_2) do
      create(:gdrive_migration_file, operation: operation, external_id: "1bGXLuClPL7w0GFB_rAga0duf5tFxkTIh_vZFbrOfW5W",
        parent_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", owner: requestee_email)
    end
    let(:request_id) { "bbbcc008-8209-4078-ba44-be50f6a668f1" }

    before do
      stub_const("#{described_class.name}::MAX_ERRORS", 2)
    end

    it "should set ingest failed" do
      VCR.use_cassette("gdrive/migration/ingest_job/multiple_errors") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_errored
        expect(file_b_1.error_type).to eq("ancestor_inaccessible")
        expect(file_b_1.error_message).to eq("Parent of folder #{file_b_1.parent_id} is inaccessible")

        request.setup_ingest([file_b_2.external_id])
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)

        file_b_2.reload
        expect(file_b_2).to be_errored
        expect(file_b_2.error_type).to eq("ancestor_inaccessible")
        expect(file_b_2.error_message).to eq("Parent of folder #{file_b_2.parent_id} is inaccessible")

        request.reload
        expect(request.ingest_progress).to eq(2)
        expect(request.error_count).to eq(2)
        expect(request.ingest_status).to eq("failed")
        expect(request.status).to eq("ingest_failed")
        expect(request.file_count).to eq(0)
      end
    end
  end

  describe "folder map with a bad dest_id but folder exists" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1CUk2Z1Qg52TcjWYFvUuqngL3brXa0Xv2", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1cB-qwVowTr6cFIEHa-E3M-fpk6JMMmpUW1JIITP6TUE",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let(:request_id) { "ce0fd796-b4ed-4b6c-be57-20ef4de74bc7" }

    before do
      folder_map_b.update!(dest_id: "xyz")
    end

    it "should find and use the dest folder" do
      VCR.use_cassette("gdrive/migration/ingest_job/bad_dest_id_but_folder_exists") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_transferred
        expect { folder_map_b.reload }.to raise_error(ActiveRecord::RecordNotFound)
        GDrive::Migration::FolderMap.find_by!(name: "Folder B", src_id: file_b_1.parent_id)
      end
    end
  end

  # Before running this spec, ensure that Folder B does NOT exist in the shared drive
  describe "folder map with a bad dest_id and dest folder doesn't exist" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1CUk2Z1Qg52TcjWYFvUuqngL3brXa0Xv2", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1uPHTd2fm_Er5D34yREXW5fgTSEOdcyPoZ6zcJ2c0Svo",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let(:request_id) { "877d7570-877f-478c-b3ac-eda91b71e3f6" }

    before do
      folder_map_b.update!(dest_id: "xyz")
    end

    it "should create the dest folder" do
      VCR.use_cassette("gdrive/migration/ingest_job/bad_dest_id_and_no_folder") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_transferred
        expect { folder_map_b.reload }.to raise_error(ActiveRecord::RecordNotFound)
        GDrive::Migration::FolderMap.find_by!(name: "Folder B", src_id: file_b_1.parent_id)
      end
    end
  end

  describe "source file with a stored reference to a parent folder that no longer exists" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1CLjCdL5-73nj5aybzafYyucgGpI9kFfaKR5TB8QLtOs",
        parent_id: "xyz", owner: requestee_email)
    end
    let(:request_id) { "9c75f009-5253-4516-b8f7-6139e73c8c9d" }

    it "should fail gracefully" do
      VCR.use_cassette("gdrive/migration/ingest_job/file_with_missing_parent") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)
        file_b_1.reload
        expect(file_b_1).to be_errored
        expect(file_b_1.error_type).to eq("client_error_ensuring_tree")
        expect(file_b_1.error_message).to eq("notFound: File not found: xyz.")
      end
    end
  end

  describe "source file with no stored reference, and it's not in the migration tree" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1ocLaGwSn97tTpZa1o_UbfJJXM1rFqhcA8CQyCIWMRKs",
        parent_id: "13dcZ65dZ5H-npYmvrlLBGsSyC0EzpEsm", owner: requestee_email)
    end
    let(:request_id) { "25a4f5bc-38cc-40bc-867f-f3333d66be72" }

    before do
      file_b_1.destroy
    end

    it "should still migrate file and create File record" do
      VCR.use_cassette("gdrive/migration/ingest_job/file_with_no_record_and_not_in_tree") do
        described_class.perform_now(cluster_id: Defaults.cluster.id,
          request_id: request.id)

        request.reload
        expect(request).to be_ingest_done
        expect(request).to be_done
        expect(request.file_count).to eq(0)
      end
    end
  end

  describe "error when moving file to temp drive" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1fGgtI-ynyMIzi7Tp2d8bwY542jrbmAnz", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "1yWXMPJnSpso__yXpopV_WZ-kBj39GJi-", src_parent_id: folder_map_a.src_id,
        dest_id: "14huMaHzvNxvfxdoQPqm3fLVOT0I1oDk-", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "11jdjwgwY0duK5kMMb8b97tuvCH8TC_aDtXvAXs7N2tU",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let!(:file_c_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1obo1kO6zdxnBZE9DpCfjSQk9-tVUp8u_QKR9XtzmsSI",
        parent_id: folder_map_c.src_id, owner: requestee_email)
    end
    let!(:file_root_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1TYsGVe0Vro-wCIMG_sk4aIiko5PPM8N0c8KwN1eXkMY",
        parent_id: operation.src_folder_id, owner: requestee_email)
    end
    let(:request_id) { "51e86502-b047-4c06-9a7c-e9fa35137858" }
    subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, request_id: request.id) }

    it "should fail gracefully" do
      VCR.use_cassette("gdrive/migration/ingest_job/client_error_moving_to_temp_drive") do
        allow_any_instance_of(GDrive::Wrapper).to receive(:update_file) do
          raise Google::Apis::ClientError.new("foo")
        end

        perform_job
        file_b_1.reload
        expect(file_b_1).to be_errored
        expect(file_b_1.error_type).to eq("client_error_moving_to_temp_drive")
        expect(file_b_1.error_message).to eq("foo")
      end
    end
  end

  describe "error when moving file to destination" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1fGgtI-ynyMIzi7Tp2d8bwY542jrbmAnz", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "1yWXMPJnSpso__yXpopV_WZ-kBj39GJi-", src_parent_id: folder_map_a.src_id,
        dest_id: "14huMaHzvNxvfxdoQPqm3fLVOT0I1oDk-", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "11jdjwgwY0duK5kMMb8b97tuvCH8TC_aDtXvAXs7N2tU",
        parent_id: folder_map_b.src_id, owner: requestee_email)
    end
    let!(:file_c_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1obo1kO6zdxnBZE9DpCfjSQk9-tVUp8u_QKR9XtzmsSI",
        parent_id: folder_map_c.src_id, owner: requestee_email)
    end
    let!(:file_root_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "1TYsGVe0Vro-wCIMG_sk4aIiko5PPM8N0c8KwN1eXkMY",
        parent_id: operation.src_folder_id, owner: requestee_email)
    end
    let(:request_id) { "51e86502-b047-4c06-9a7c-e9fa35137858" }
    subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, request_id: request.id) }

    it "should fail gracefully" do
      VCR.use_cassette("gdrive/migration/ingest_job/client_error_moving_to_destination") do
        call_count = 0
        allow_any_instance_of(GDrive::Wrapper).to receive(:update_file) do
          if call_count == 1
            raise Google::Apis::ClientError.new("foo")
          end
          call_count += 1
        end

        perform_job
        file_b_1.reload
        expect(file_b_1).to be_errored
        expect(file_b_1.error_type).to eq("client_error_moving_to_destination")
        expect(file_b_1.error_message).to eq("foo")
      end
    end
  end

  describe "requested file is not owned by requestee" do
    let!(:folder_map_a) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder A",
        src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_", src_parent_id: operation.src_folder_id,
        dest_id: "1REPQUYEGym1APlylgINdZFO1Lh85eDq4", dest_parent_id: operation.dest_folder_id)
    end
    let!(:folder_map_b) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder B",
        src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV", src_parent_id: folder_map_a.src_id,
        dest_id: "1fGgtI-ynyMIzi7Tp2d8bwY542jrbmAnz", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:folder_map_c) do
      create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
        src_id: "1yWXMPJnSpso__yXpopV_WZ-kBj39GJi-", src_parent_id: folder_map_a.src_id,
        dest_id: "14huMaHzvNxvfxdoQPqm3fLVOT0I1oDk-", dest_parent_id: folder_map_a.dest_id)
    end
    let!(:file_b_1) do
      create(:gdrive_migration_file, operation: operation, external_id: "11jdjwgwY0duK5kMMb8b97tuvCH8TC_aDtXvAXs7N2tU",
        parent_id: folder_map_b.src_id, owner: "rando@example.com")
    end
    let(:request_id) { "51e86502-b047-4c06-9a7c-e9fa35137858" }
    subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, request_id: request.id) }

    it "should skip the file" do
      VCR.use_cassette("gdrive/migration/ingest_job/file_not_owned_by_requestee") do
        perform_job
        file_b_1.reload
        request.reload
        expect(file_b_1).not_to be_errored
        expect(request.error_count).to eq(0)
      end
    end
  end
end
