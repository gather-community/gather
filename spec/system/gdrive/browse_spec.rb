# frozen_string_literal: true

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
      let!(:drive1) do
        create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0AGH_tsBj1z-0Uk9PVA",
                             group: group1)
      end
      let!(:item_group1) { create(:gdrive_item_group, item: drive1, group: group1) }
      let!(:drive2) do
        create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0ABQKSPvPdtPNUk9PVA",
                             group: group2)
      end
      let!(:item_group2) { create(:gdrive_item_group, item: drive2, group: group2) }
      let!(:missing_drive) do
        create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "73bh83UGIkb6BKhBbKb",
                             group: group1, missing: true)
      end
      let!(:item_group3) { create(:gdrive_item_group, item: missing_drive, group: group1) }
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

        scenario "authorization error perhaps from expired refresh token" do
          VCR.use_cassette("gdrive/browse/authorization_error") do
            visit(gdrive_home_path)
            expect(page).to have_content("There was an error connecting to Google Drive. "\
              "Please notify a Gather Admin.")

            visit(root_path)
            expect(page).not_to have_content("There was an error connecting to Google Drive. "\
              "Please notify a Gather Admin.")

            # Second visit to the page should show same error but via a different code path.
            visit(gdrive_home_path)
            expect(page).to(have_content("There was an error connecting to Google Drive. "\
              "Please notify a Gather Admin."))
          end
        end

        scenario "explicit drive ID given for non-existent drive" do
          visit(gdrive_folder_path(folder_id: "xyzw123", drive: 1))
          expect(page).to have_content("page you were looking for doesn't exist")
        end

        scenario "explicit drive ID given for existent but inaccessible drive" do
          visit(gdrive_folder_path(folder_id: drive2.external_id, drive: 1))
          expect(page).to have_content("page you were looking for doesn't exist")
        end

        scenario "explicit drive ID given for existent but missing drive" do
          visit(gdrive_folder_path(folder_id: missing_drive.external_id, drive: 1))
          expect(page).to have_content("page you were looking for doesn't exist")
        end

        scenario "explicit folder ID given for non-existent folder" do
          VCR.use_cassette("gdrive/browse/non_existent_folder") do
            visit(gdrive_folder_path(folder_id: "xyzw123"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        scenario "explicit folder ID given for unknown drive" do
          # A cassette is required here because we need to fetch the folder to find out what
          # drive it belongs to before we can check the drive and realize it's inaccessible.
          # This cassette returns that the folder below is in a drive we have no record of.
          VCR.use_cassette("gdrive/browse/folder_id_in_unknown_drive") do
            visit(gdrive_folder_path(folder_id: "1R-5rrk68UIdYcidp61CZ54fnLMSiakEi"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        scenario "explicit folder ID given for drive with no permission" do
          # A cassette is required here because we need to fetch the folder to find out what
          # drive it belongs to before we can check the drive and realize it's not permitted.
          # This cassette returns that the folder below is in drive2, which is attached to an empty group.
          VCR.use_cassette("gdrive/browse/folder_id_in_forbidden_drive") do
            visit(gdrive_folder_path(folder_id: "1R-5rrk68UIdYcidp61CZ54fnLMSiakEi"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        # scenario "happy path" do
        # end
      end

      # context "with multiple permitted drives" do
      #   let!(:drive) do
      #     create(:gdrive_item, gdrive_config: config, external_id: "0ABQKSPvPdtPNUk9PVA",
      #                          kind: "drive", group: group)
      #   end
      #   let!(:folder) do
      #     create(:gdrive_item, gdrive_config: config, external_id: "0ABQKSPvPdtPNUk9PVA",
      #                          kind: "folder", group: group)
      #   end
      #   let!(:file) do
      #     create(:gdrive_item, gdrive_config: config, external_id: "0ABQKSPvPdtPNUk9PVA",
      #                          kind: "folder", group: group)
      #   end
      #
      #   # Folders and files shouldn't be shown at top level
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

    context "when config present" do
      let!(:config) { create(:gdrive_main_config, org_user_id: "a@example.com") }
      let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com") }

      context "when no shared drives present" do
        scenario "it shows message" do
          visit(gdrive_home_path)
          expect(page).to have_content("Your community is not yet connected to Google Drive. "\
            "You can click 'Setup' above to get started.")
        end
      end

      context "when shared drive present" do
        let!(:drive) do
          create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0AGH_tsBj1z-0Uk9PVA")
        end

        scenario "authorization error perhaps from expired refresh token" do
          VCR.use_cassette("gdrive/browse/admin_authorization_error") do
            visit(gdrive_home_path)
            expect(page).to(have_content("There was an error connecting to Google Drive. "\
              "Please click 'Setup' above to re-connect"))
          end
        end
      end
    end
  end
end
