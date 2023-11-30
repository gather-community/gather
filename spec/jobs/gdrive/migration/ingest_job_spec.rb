# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::IngestJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Set a valid consenter email (regular Google account) and org_user_id (Google Workspace account).
  # - Create a destination Shared Drive for the migration inside your Google Workspace account.
  # - Under the consenter email, create a source folder/file structure in Drive as follows:
  #   - Gather Migration Test Source Folder
  #     - Folder A
  #       - Folder B
  #         - File B.1
  #       - Folder C
  #         - File C.1
  #     - File Root.1
  # - Share the source folder with your org_user_id.
  # - Update src and dest folder IDs in the operation below.
  # - Update the src_ids in the folder maps below.
  # - Create a ConsentRequest in dev mode under the consenter email and load the pick page.
  # - Get a fresh main access_token from the DB after viewing the main GDrive page and add it below.
  # - Get a fresh migration access_token from the DB after viewing the pick page in the consent process and add it below.
  #
  # For each real run:
  # - Ensure the destination Shared Drive is empty.
  # - Delete all migration temp drives.
  # - Create new File B.1, C.1, Root.1 if necessary.
  # - Update the external_ids in the file records below to match the new files.
  # - Pick files B.1, C.1, and Root.1 using the Google Picker in the consent process.
  # - Delete any casettes under spec/cassettes/gdrive/migration/ingest_job that you want to adjust.
  #
  # Before committing:
  # - Remove tokens and real email addresses.

  let(:consenter_email) { "consenter@example.com" }
  let!(:main_config) { create(:gdrive_main_config, org_user_id: "admin@example.org") }
  let!(:main_token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id) }
  let!(:migration_config) { create(:gdrive_migration_config) }
  let!(:migration_token) { create(:gdrive_token, gdrive_config: migration_config, google_user_id: consenter_email) }
  let!(:operation) do
    create(:gdrive_migration_operation, config: migration_config, dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq")
  end
  let!(:folder_map_a) do
    create(:gdrive_migration_folder_map, operation: operation, src_id: "1PJwkZgkByPMcbkfzneq65Cx1CnDNMVR_",
      src_parent_id: operation.src_folder_id, name: "Folder A")
  end
  let!(:folder_map_b) do
    create(:gdrive_migration_folder_map, operation: operation, src_id: "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV",
      src_parent_id: folder_map_a.src_id, name: "Folder B")
  end
  let!(:folder_map_c) do
    create(:gdrive_migration_folder_map, operation: operation, src_id: "1r-Xx_1mI-34JChXqeKdUg4J1ok6J-pZZ",
      src_parent_id: folder_map_a.src_id, name: "Folder C")
  end
  let!(:file_b_1) do
    create(:gdrive_migration_file, operation: operation, external_id: "1fEl506bog-p83ZrCiDkv-lgvGa5uQrSU4jMb4D-pKDk",
      parent_id: folder_map_b.src_id, owner: consenter_email)
  end
  let!(:file_c_1) do
    create(:gdrive_migration_file, operation: operation, external_id: "194qPqi0ulPTDEEbhHy_Uf-4iRdQHHOaDhC9CjhpFFnw",
      parent_id: folder_map_c.src_id, owner: consenter_email)
  end
  let!(:file_root_1) do
    create(:gdrive_migration_file, operation: operation, external_id: "1dLoyEGGapNBqeZaS5_rNV6tZiq9fbBqNkxgGmJlTVzs",
      parent_id: operation.src_folder_id, owner: consenter_email)
  end
  let!(:consent_request) do
    # We need a known ID value or it may not match what's in the cassette.
    create(:gdrive_migration_consent_request, id: 537716653, operation: operation,
      google_email: consenter_email, file_count: 3)
  end

  before do
    allow(described_class).to receive(:random_request_id).and_return("0f89fbef-0e56-42d8-9364-6b423eb489ad")
  end

  describe "happy path" do
    it "creates temp drive, creates and reuses parent folders, double-moves files, updates statuses" do
      VCR.use_cassette("gdrive/migration/ingest_job/happy_path") do
        # First time, ingest file_b_1, which creates folders B and A
        consent_request.update!(
          ingest_requested_at: Time.current,
          ingest_file_ids: [file_b_1.external_id],
          ingest_status: "new"
        )
        described_class.perform_now(cluster_id: Defaults.cluster.id, community_id: Defaults.community.id,
          consent_request_id: consent_request.id)

        consent_request.reload
        expect(consent_request).to be_ingest_done
        expect(consent_request).to be_in_progress
        expect(consent_request.file_count).to eq(2)
        folder_map_b.reload
        expect(folder_map_b.dest_id).not_to be_nil
        expect(folder_map_b.dest_parent_id).not_to be_nil
        folder_map_a.reload
        expect(folder_map_a.dest_id).not_to be_nil
        expect(folder_map_a.dest_parent_id).not_to be_nil
        file_b_1.reload
        expect(file_b_1).to be_transferred
        file_c_1.reload
        expect(file_c_1).to be_pending

        # Second time, ingest:
        # - file_c_1, which creates folder C and reuses folder A
        # - file_root_1, which demonstrates multiple ingestions per job
        #
        # These are also the last files for the consenting user so we should mark the request done.
        consent_request.update!(
          ingest_requested_at: Time.current,
          ingest_file_ids: [file_c_1.external_id, file_root_1.external_id],
          ingest_status: "new"
        )
        described_class.perform_now(cluster_id: Defaults.cluster.id, community_id: Defaults.community.id,
          consent_request_id: consent_request.id)

        consent_request.reload
        expect(consent_request).to be_ingest_done
        expect(consent_request).to be_done
        expect(consent_request.file_count).to eq(0)
        folder_map_c.reload
        expect(folder_map_c.dest_id).not_to be_nil
        expect(folder_map_c.dest_parent_id).not_to be_nil
        file_c_1.reload
        expect(file_c_1).to be_transferred
        file_root_1.reload
        expect(file_root_1).to be_transferred
      end
    end
  end
end
