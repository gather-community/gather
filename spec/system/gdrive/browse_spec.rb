# Copy in the data in the dev config# frozen_string_literal: true

require "rails_helper"

describe "gdrive browse", js: true do
  include_context "gdrive"

  before do
    create(:feature_flag, name: "gdrive", status: true)
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as regular user" do
    let!(:actor) { create(:user) }

    context "when config not present" do
      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. "\
          "Please talk to a Gather Admin about getting Google Drive set up.")
      end
    end

    context "when wrapper not authenticated" do
      let!(:config) { create(:gdrive_main_config) }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. "\
          "Please talk to a Gather Admin about getting Google Drive set up.")
      end
    end

    context "when no shared drives present" do
      let!(:config) { create(:gdrive_main_config, org_user_id: "a@example.com") }
      let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com") }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. "\
          "Please talk to a Gather Admin about getting Google Drive set up.")
      end
    end

    context "when authenticated and shared drive present" do
      let!(:config) { create(:gdrive_main_config, org_user_id: "a@example.com") }
      let!(:group1) { create(:group, joiners: group1_joiners) }
      let!(:group2) { create(:group, joiners: []) }
      let!(:shared_drive1) do
        create(:gdrive_shared_drive, gdrive_config: config, external_id: "0AGH_tsBj1z-0Uk9PVA", group: group1)
      end
      let!(:shared_drive2) do
        create(:gdrive_shared_drive, gdrive_config: config, external_id: "0ABQKSPvPdtPNUk9PVA", group: group2)
      end
      let!(:token) do
        create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com")
      end

      context "when user has no accessible drives" do
        let(:group1_joiners) { [] }

        scenario do
          visit(gdrive_home_path)
          expect(page).to have_content("No files found.")
        end
      end

      context "when user has accessible drive" do
        let(:group1_joiners) { [actor] }

        # scenario "authorization error perhaps from expired refresh token" do
        #   shows an error message requesting gather admin to reauthenticate

        scenario "explicit drive ID given for non-existent drive", raise_server_errors: false do
          visit(gdrive_folder_path(folder_id: "xyzw123", drive: 1))
          expect(page).to have_content("ActiveRecord::RecordNotFound")
        end

        scenario "explicit drive ID given for existent but inaccessible drive" do
          visit(gdrive_folder_path(folder_id: shared_drive2.external_id, drive: 1))
          expect(page).to have_content("page you were looking for doesn't exist")
        end

        scenario "explicit folder ID given for non-existent folder" do
          VCR.use_cassette("gdrive/browse/non_existent_folder") do
            visit(gdrive_folder_path(folder_id: "xyzw123"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        scenario "explicit folder ID given for unknown drive", raise_server_errors: false do
          # A cassette is required here because we need to fetch the folder to find out what
          # drive it belongs to before we can check the drive and realize it's inaccessible.
          VCR.use_cassette("gdrive/browse/folder_id_in_unknown_drive") do
            visit(gdrive_folder_path(folder_id: "1R-5rrk68UIdYcidp61CZ54fnLMSiakEi"))
            expect(page).to have_content("ActiveRecord::RecordNotFound")
          end
        end

        # scenario "happy path" do
        # end
      end

      # context "with multiple permitted drives" do
      #   let!(:shared_drive) do
      #     create(:gdrive_shared_drive, gdrive_config: config, external_id: "0ABQKSPvPdtPNUk9PVA",
      #                                  group: group)
      #   end
      #
      #   scenario "happy path" do
      #   end
      # end
    end
  end

  context "as admin" do
    let!(:actor) { create(:admin) }

    context "when config not present" do
      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. "\
          "Please contact a Gather staff member to get started.")
      end
    end

    context "when wrapper not authenticated" do
      let!(:config) { create(:gdrive_main_config) }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. "\
          "You can click 'Setup' above to get started.")
      end
    end

    context "when no shared drives present" do
      let!(:config) { create(:gdrive_main_config, org_user_id: "a@example.com") }
      let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com") }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. "\
          "You can click 'Setup' or 'Migration' above to get started.")
      end
    end
  end
end
