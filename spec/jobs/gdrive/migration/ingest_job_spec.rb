# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::IngestJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Set a valid consenter email (regular Google account) and org_user_id (Google Workspace account).
  # - Under the consenter email, create a source folder/file structure in regular Drive as follows:
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
  # - Create a ConsentRequest in dev mode under the consenter email and load the pick page.
  # - Get a fresh migration access_token from the DB after viewing the pick page and add it below.
  #
  # For each real run:
  # - Make sure delayed job isn't running so your files don't get processed in dev mode when you pick them.
  # - Ensure the destination Shared Drive folders have no files.
  # - Delete all migration temp drives.
  # - If files got moved:
  #   - Create new File B.1, C.1, Root.1.
  #   - Update the external_ids in the file records below to match the new files.
  #   - Pick files B.1, C.1, and Root.1 using the Google Picker in the consent process.
  # - Update the request_id to a new random UUID (SecureRandom.uuid)
  # - Delete any casettes under spec/cassettes/gdrive/migration/ingest_job that you want to adjust.
  #
  # Before committing:
  # - Remove tokens and real email addresses using global find and replace.

  let(:consenter_email) { "tomsmyth@gmail.com" }
  let!(:main_config) { create(:gdrive_main_config, org_user_id: "workspace.admin@touchstonecohousing.org") }
  let!(:main_token) { create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id, access_token: "ya29.a0AfB_byDfE-BhHd7mN36oaM_AEzTPvzICAiA24BUQ-VbiZwM3JCWtRHs8ZJbtIAh19AQcRgVEdeaASVZGJd1efUo6xl1FgX_amXhaAmgzS0u3szmBtga4i1ezSq09hatCbdm7hgNmlqoyv7uQGORyCOrlnhcakaL0UwWo37oaCgYKAWYSARESFQHGX2MiaUvmBA-9H8ZPCFMwpCc91Q0174") }
  let!(:migration_config) { create(:gdrive_migration_config) }
  let!(:migration_token) { create(:gdrive_token, gdrive_config: migration_config, google_user_id: consenter_email, access_token: "ya29.a0AfB_byBw4V29X5oIg3yLQ5mWtJVod-p142iq2x2JWBvRiBeWlFFr4Yoh3PGfW37alOhOftuv03yburDzbj2WLl3bQK5P_kIDtdQeOpAkJC1Pq2vOT9GqGDWc4N9OTcf1Ufw8wIka-lVc55I3AzteFcvAzp-1dz_cT3aqvQaCgYKAZwSARMSFQHGX2MiCQ4_B0zxrJwPHa5L_3630w0173") }
  let!(:operation) do
    create(:gdrive_migration_operation, config: migration_config, dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
      src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq")
  end
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
  let!(:folder_map_c) do
    create(:gdrive_migration_folder_map, operation: operation, name: "Folder C",
      src_id: "1yWXMPJnSpso__yXpopV_WZ-kBj39GJi-", src_parent_id: folder_map_a.src_id,
      dest_id: "14huMaHzvNxvfxdoQPqm3fLVOT0I1oDk-", dest_parent_id: folder_map_a.dest_id)
  end
  let!(:file_b_1) do
    create(:gdrive_migration_file, operation: operation, external_id: "15vNLHLMuTBBqxVqvZkZcvcn5LF9XTMn-P4a2IXijdOo",
      parent_id: folder_map_b.src_id, owner: consenter_email)
  end
  let!(:file_c_1) do
    create(:gdrive_migration_file, operation: operation, external_id: "1jkDIn31dWj9TenZQ-qjpP8pMN2bGqEpiP1wciZ1ykE0",
      parent_id: folder_map_c.src_id, owner: consenter_email)
  end
  let!(:file_root_1) do
    create(:gdrive_migration_file, operation: operation, external_id: "1UKLwGkmZbP6e5RFHWY_tO1gMe0P93lFPBoL14Jd14rc",
      parent_id: operation.src_folder_id, owner: consenter_email)
  end
  let!(:consent_request) do
    # We need a known ID value or it may not match what's in the cassette.
    create(:gdrive_migration_consent_request, id: 537716653, operation: operation,
      google_email: consenter_email, file_count: 3)
  end
  let(:request_id) { "7834be73-9b89-4958-97f3-5f36ebb3cca9" }

  before do
    allow(described_class).to receive(:random_request_id).and_return(request_id)
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

        # We ingested one file so there should be 3 - 1 = 2 left now
        expect(consent_request.file_count).to eq(2)
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
        file_c_1.reload
        expect(file_c_1).to be_transferred
        file_root_1.reload
        expect(file_root_1).to be_transferred
      end
    end
  end
end
