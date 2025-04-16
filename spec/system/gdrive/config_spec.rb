# frozen_string_literal: true

require "rails_helper"

describe "gdrive items", js: true do
  include_context "gdrive"

  # Manual prep
  # - Open the GDrive page on the dev server
  # - Authenticate to GDrive
  # - Open the console and select your tenant
  # - GDrive::Token.all
  # - Copy the access_token value
  # - Pass it to the :gdrive_token factory as `access_token`
  # - Once the test is passing,
  #   - Remove the explict access_token param from the token factory call
  #   - Replace real email addresses with fake ones in both factory calls and cassettes

  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "with no config" do
    visit(gdrive_config_path)
    fill_in("Google Workspace User ID", with: "admin@example.com")
    fill_in("App Client ID", with: "1234567-abcdefg.apps.googleusercontent.com")
    click_on("Save")

    expect(page).to have_content("Must be exactly 35 characters")
    fill_in("App Client Secret", with: "53VUKh3CKKWOgKY1yn4BaPfaDYpFXMweg5er")
    click_on("Save")

    expect_success("Config updated successfully.")
    expect(page).to have_content("Authenticate With Google")
  end

  context "with config" do
    let!(:config) { create(:gdrive_main_config, org_user_id: "admin@example.com") }

    context "no valid access token" do
      context "with no mapped drives" do
        scenario do
          visit(gdrive_config_path)
          expect(page).to have_content("Your community is not yet connected to Google Drive.")
        end
      end

      context "with mapped drives" do
        let!(:item) { create(:gdrive_item, gdrive_config: config) }

        scenario do
          visit(gdrive_config_path)
          expect(page).to have_content("Your community needs to be reconnected to Google Drive.")
        end
      end
    end

    context "with config and token" do
      # Manual prep
      # - In the target Workspace account:
      #   - create a drive named "Drive 1"
      #   - create a folder in the drive named "Folder 1"
      #   - create a file in the folder named "File 1"
      # - Copy their IDs below.
      let(:drive_id) { "0ANh47wT0lLbTUk9PVA" }
      let(:folder_id) { "15Y3FzxJHdpCv421PPHCcwu_dMFRx5Y9P" }
      let(:file_id) { "1AUjr0Tq8np0zDC0iGc38niQzVGjZKS5aqTyl5h2kMqI" }
      let!(:group) { create(:group, name: "Stuff") }
      let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: config.org_user_id, access_token: "ya29.a0AfB_byC0wLkre3kl_csP4ljARYrefwUhJVyB07sneGBVn54suDLn1kv_JY5TfycBavpQPu5lHPutSi0qiGGzF653b-I9Tb6g0YFXLLsKRFyw92MRTw2bt7sy4TEbP6THf7m6SdG1O068gPVaLtGe2MewwvMlGHBpPlYKxQaCgYKAboSARESFQHGX2MiosOp6nr60oZleOl-au9EZg0173") }

      scenario "happy path" do
        # Can't match on body because the boundary changes to something random every time
        # and I'm not sure how to set it to something known.
        VCR.use_cassette("gdrive/items/happy_path", match_requests_on: %i[method uri host path]) do
          visit(gdrive_config_path)
          expect(page).to have_content("No shared drives linked to Gather")

          click_on("Link Item")
          select("Drive", from: "Type")
          fill_in("ID", with: drive_id)
          click_on("Save")
          expect(page).to have_content("Drive 1")

          expect do
            click_on("Add Group")
            select("Stuff", from: "Group")
            select("Viewer", from: "Access Level")
            click_on("Save")
            expect(page).to have_content("Stuff: Viewer")
          end.to have_enqueued_job(GDrive::ItemPermissionSyncJob)

          click_on("Link Item")
          select("Folder", from: "Type")
          fill_in("ID", with: folder_id)
          click_on("Save")
          expect(page).to have_content(/Folders.+Folder 1/m)

          # Link a file but pick folder by mistake
          click_on("Link Item")
          select("Folder", from: "Type")
          fill_in("ID", with: file_id)
          click_on("Save")
          expect(page).to have_content(/Folders.*Folder 1.*Files.*File 1/m)

          # Link a non-existent drive
          click_on("Link Item")
          select("Drive", from: "Type")
          fill_in("ID", with: "xyz")
          click_on("Save")
          expect(page).to have_content(/[xyz].*Inaccessible/m)

          # Remove group from drive (should enqueue job)
          expect do
            accept_confirm { find("i.fa-times").click }
            expect(page).not_to have_content("Stuff")
          end.to have_enqueued_job(GDrive::ItemPermissionSyncJob)

          # Remove Drive 1 (it appears below the non-existent drive so it's the 2nd trash icon)
          accept_confirm { all("i.fa-trash")[1].click }
          expect(page).not_to have_content("Drive 1")
        end
      end
    end
  end

  # Manual prep
  # - Ensure token works
  scenario "revoke authorization" do
  end
end
