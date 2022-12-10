# Copy in the data in the dev config# frozen_string_literal: true

require "rails_helper"

describe "gdrive browse", js: true do
  include_context "gdrive"

  let!(:actor) { create(:user) }

  before do
    create(:feature_flag, name: "gdrive", status: true)
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "when saved credentials and folder are present" do
    let!(:gdrive_config) { create(:gdrive_main_config, folder_id: "0B24us5XZC4JyX21yUUw3aHBEYlU") }

    scenario "it shows files" do
      VCR.use_cassette("gdrive/folders/creds_and_folder_present/success") do
        visit(gdrive_home_path)
        expect(page).to have_content("Book of Agreements")
        click_on("Common House")
        expect(page).to have_content("3D printer")
      end
    end

    scenario "it shows message if no files found" do
      VCR.use_cassette("gdrive/folders/creds_and_folder_present/no_files") do
        visit(gdrive_home_path)
        expect(page).to have_content("No files found in this folder")
      end
    end
  end

  context "when saved credentials are not present" do
    let!(:gdrive_config) { create(:gdrive_main_config, folder_id: nil) }

    scenario "it shows message" do
      visit(gdrive_home_path)
      expect(page).to have_content("Your community has not yet been configured")
    end
  end
end
