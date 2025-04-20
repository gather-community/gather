# frozen_string_literal: true

require "rails_helper"

describe "gdrive auth index", js: true do
  include_context "gdrive"

  let!(:actor) { create(:admin) }
  let(:url) { "http://gatherdev.org:31337/gdrive/auth?community_id=#{Defaults.community.id}" }

  before do
    create(:feature_flag, name: "gdrive", status: true)
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  # context "when saved credentials and folder are present" do
  #   let!(:gdrive_config) { create(:gdrive_config, folder_id: "0B24us5XZC4JyX21yUUw3aHBEYlU") }

  #   context "when fetching folder succeeds" do
  #     scenario "it shows connected status and folder name, option to reset" do
  #       VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/success") do
  #         visit(url)
  #         expect(page).to have_content("Touchstone Documents")
  #         expect(page).to have_content("Reset Connection")

  #         accept_confirm { click_on("Reset Connection") }
  #         expect(page).to have_content("Authenticate With Google")
  #       end
  #     end
  #   end

  #   context "when fetching folder fails with server error" do
  #     scenario "it shows error information, option to reset" do
  #       VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/server_error") do
  #         visit(url)
  #         expect(page).to have_content("server error")
  #         expect(page).to have_content("Reset Connection")
  #       end
  #     end
  #   end

  #   context "when fetching folder fails with 404" do
  #     let!(:gdrive_config) { create(:gdrive_config, folder_id: "0B24us5XZC4JyX21yUUw3aHBEYl") }

  #     scenario "it shows error information, option to reset" do
  #       # We don't want to just let them pick a new folder as that would blow up sync.
  #       # folder_id should be considered immutable.
  #       # They can either try to get it to work or reset and start over.
  #       # In this spec we can just show that the reset link is shown.
  #       # In another spec we'll cover the big warning that should be shown, etc.
  #       VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/not_found") do
  #         visit(url)
  #         expect(page).to have_content("could not be found")
  #         expect(page).to have_content("Reset Connection")
  #       end
  #     end
  #   end

  #   context "when fetching folder fails with 401" do
  #     scenario "it shows error information, option to re-auth with login hint, option to reset" do
  #       VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/invalid_creds") do
  #         visit(url)
  #         expect(page).to have_content("authorization error")
  #         expect(page).to have_content("Authenticate With Google")

  #         link = find("a", text: "Authenticate With Google")
  #         expect(link["href"]).to include("login_hint=abc123@gmail.com")

  #         expect(page).to have_content("Reset Connection")
  #       end
  #     end
  #   end

  #   context "when fetching folder fails with other error" do
  #     scenario "it does not handle the error", js: false do
  #       assert_raises(Google::Apis::ClientError) do
  #         VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/other_error") do
  #           visit(url)
  #         end
  #       end
  #     end
  #   end
  # end

  # context "when saved credentials are present but no folder" do
  #   let!(:gdrive_config) { create(:gdrive_config, folder_id: nil) }

  #   it "shows need to pick folder link, option to reset" do
  #     VCR.use_cassette("gdrive/auth/index/folder_not_present") do
  #       visit(url)
  #       expect(page).to have_css("button", text: "Pick Your Community's Root Folder")
  #       expect(page).to have_content("Reset Connection")
  #       click_on("Pick Your Community's Root Folder")
  #       expect(page).to have_content("Touchstone Documents")
  #     end
  #   end
  # end

  # context "when no saved credentials are present" do
  #   it "shows need to authenticate link, no option to reset" do
  #     visit(url)
  #     expect(page).to have_css("a", text: "Authenticate With Google")
  #     link = find("a", text: "Authenticate With Google")

  #     # Ensure we are requesting to return back to correct URL.
  #     expect(link["href"]).to include("%22current_uri%22:%22#{url}%22")
  #     expect(page).not_to have_content("Reset Connection")
  #   end
  # end
end
