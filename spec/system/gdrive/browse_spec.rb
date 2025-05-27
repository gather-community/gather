# frozen_string_literal: true

require "rails_helper"

# To develop on this spec, if the code you're workign on needs to make calls to the GDrive API,
# 1. Open the GDrive page on the dev server
# 2. Authenticate to GDrive
# 3. Open the console and select your tenant.
# 4. GDrive::Token.all
# 5. Copy the access_token value
# 6. Pass it to the :gdrive_token factory as `access_token`
# 7. Wrap your test code in a VCR cassette
# 8. Run the test. The API call should work and the request should be captured.
# 9. Once the test is passing, update all occurrences of the access_token in the cassette with `ya29.xxx`
# 10. Remove the explict access_token param from the token factory call.
describe "gdrive browse", js: true do
  include_context "gdrive"

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as regular user" do
    let!(:actor) { create(:user) }

    context "when config not present" do
      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. " \
          "Please talk to a Gather Admin.")
      end
    end

    context "when wrapper not authenticated" do
      let!(:config) { create(:gdrive_config) }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. " \
          "Please talk to a Gather Admin.")
      end
    end

    context "when no shared drives present" do
      let!(:config) { create(:gdrive_config, org_user_id: "a@example.com") }
      let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com") }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. " \
          "Please talk to a Gather Admin.")
      end
    end

    context "when authenticated and shared drive present" do
      let!(:config) { create(:gdrive_config, org_user_id: "a@example.com") }
      let!(:group1) { create(:group, joiners: group1_joiners) }
      let!(:group2) { create(:group, joiners: group2_joiners) }
      let!(:drive1) do
        create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0AGH_tsBj1z-0Uk9PVA")
      end
      let!(:item_group1) { create(:gdrive_item_group, item: drive1, group: group1) }
      let!(:drive2) do
        create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0ABQKSPvPdtPNUk9PVA")
      end
      let!(:item_group2) { create(:gdrive_item_group, item: drive2, group: group2) }
      let!(:token) do
        create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com")
      end

      context "when user has no accessible drives" do
        let(:group1_joiners) { [] }
        let(:group2_joiners) { [] }

        scenario do
          visit(gdrive_home_path)
          expect(page).to have_content("No files found.")
        end
      end

      context "when user has one accessible drive" do
        let(:group1_joiners) { [actor] }
        let(:group2_joiners) { [] }

        scenario "authorization error perhaps from expired refresh token" do
          VCR.use_cassette("gdrive/browse/authorization_error") do
            visit(gdrive_home_path)
            expect(page).to have_content("Your community needs to be reconnected to Google Drive. " \
              "Please notify a Gather Admin.")

            visit(root_path)
            expect(page).not_to have_content("Your community needs to be reconnected to Google Drive. " \
              "Please notify a Gather Admin.")

            # Second visit to the page should show same error but via a different code path.
            visit(gdrive_home_path)
            expect(page).to(have_content("Your community needs to be reconnected to Google Drive. " \
              "Please notify a Gather Admin."))
          end
        end

        scenario "explicit drive ID given for non-existent drive" do
          visit(gdrive_browse_path(item_id: "xyzw123", drive: 1))
          expect(page).to have_content("page you were looking for doesn't exist")
        end

        scenario "explicit drive ID given for existent but inaccessible drive" do
          visit(gdrive_browse_path(item_id: drive2.external_id, drive: 1))
          expect(page).to have_content("page you were looking for doesn't exist")
        end

        scenario "explicit folder ID given for non-existent folder" do
          VCR.use_cassette("gdrive/browse/non_existent_folder") do
            visit(gdrive_browse_path(item_id: "xyzw123"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        scenario "explicit folder ID given for unknown drive" do
          # A cassette is required here because we need to fetch the folder to find out what
          # drive it belongs to before we can check the drive and realize it's inaccessible.
          # This cassette returns that the folder below is in a drive we have no record of.
          VCR.use_cassette("gdrive/browse/folder_id_in_unknown_drive") do
            visit(gdrive_browse_path(item_id: "1R-5rrk68UIdYcidp61CZ54fnLMSiakEi"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        scenario "explicit folder ID given for drive with no permission" do
          # A cassette is required here because we need to fetch the folder to find out what
          # drive it belongs to before we can check the drive and realize it's not permitted.
          # This cassette returns that the folder below is in drive2, which is attached to an empty group.
          VCR.use_cassette("gdrive/browse/folder_id_in_forbidden_drive") do
            visit(gdrive_browse_path(item_id: "1R-5rrk68UIdYcidp61CZ54fnLMSiakEi"))
            expect(page).to have_content("page you were looking for doesn't exist")
          end
        end

        scenario "happy path - land on page, see folders in drive, click folder, click file" do
          VCR.use_cassette("gdrive/browse/one_drive_happy_path") do
            visit(gdrive_home_path)
            click_on("Folder A")
            expect(page).to have_link("Doc 2")
          end
        end
      end

      context "with multiple permitted drives" do
        let(:group1_joiners) { [actor] }
        let(:group2_joiners) { [actor] }

        let!(:folder) do
          create(:gdrive_item, gdrive_config: config, external_id: "1R-5rrk68UIdYcidp61CZ54fnLMSiakEi",
            kind: "folder", name: "")
        end
        let!(:item_group4) { create(:gdrive_item_group, item: folder, group: group1) }
        let!(:file) do
          create(:gdrive_item, gdrive_config: config, external_id: "1s5sjHHrXaVxw5OqlmtZKR2b_GR5qMr8KASfsG9w3dz4",
            kind: "file")
        end
        let!(:item_group5) { create(:gdrive_item_group, item: file, group: group1) }

        # Folders and files shouldn't be shown at top level
        scenario("happy path - land on page, see both drives, click one, click folder") do
          VCR.use_cassette("gdrive/browse/multi_drive_happy_path") do
            visit(gdrive_home_path)
            within(".item-list") do
              expect(page).to have_content("Gather Drive Test A")
              expect(page).not_to have_content("Folder")
              expect(page).not_to have_content("File")
            end
            click_on("Gather Drive Test A")
            click_on("Folder A")
            expect(page).to(have_link("Doc 2"))
          end
        end
      end
    end
  end

  context "as admin" do
    let!(:actor) { create(:admin) }

    context "when config not present" do
      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive. " \
          "Please go to the settings page to get started")
      end
    end

    context "when wrapper not authenticated" do
      let!(:config) { create(:gdrive_config) }

      scenario "it shows message" do
        visit(gdrive_home_path)
        expect(page).to have_content("Your community is not yet connected to Google Drive.\n" \
          "Please authenticate with Google")
      end
    end

    context "when config present" do
      let!(:config) { create(:gdrive_config, org_user_id: "a@example.com") }
      let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "a@example.com") }

      context "when no shared drives present" do
        scenario "it shows message" do
          visit(gdrive_home_path)
          expect(page).to have_content("Your community does not have any linked Shared Drives. " \
            "Please go to the settings page to link a drive")
        end
      end

      context "when permitted shared drive present" do
        let!(:drive) do
          create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0AGH_tsBj1z-0Uk9PVA")
        end
        let!(:group) { create(:group, joiners: [actor]) }
        let!(:item_group) { create(:gdrive_item_group, item: drive, group: group) }

        scenario "authorization error perhaps from expired refresh token" do
          VCR.use_cassette("gdrive/browse/admin_authorization_error") do
            visit(gdrive_home_path)
            expect(page).to(have_content("Your community needs to be reconnected to Google Drive.\n" \
              "Please authenticate with Google"))
          end
        end
      end
    end
  end
end
