# frozen_string_literal: true

require "rails_helper"

describe "gdrive auth index", js: true do
  let(:actor) { create(:admin) }

  before do
    create(:feature_flag, name: "gdrive", status: true)
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  shared_examples_for "need to connect" do
    it "shows need to connect and button" do
    end
  end

  context "when saved credentials and folder are present" do
    let!(:gdrive_config) { create(:gdrive_config, folder_id: "0B24us5XZC4JyX21yUUw3aHBEYlU") }

    context "when fetching folder succeeds" do
      scenario "it shows connected status and folder name" do
        VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/success") do
          visit(gdrive_auth_path)
          expect(page).to have_content("Touchstone Documents")
        end
      end
    end

    context "when fetching folder fails with server error" do
      scenario "it shows connected status and folder name" do
        VCR.use_cassette("gdrive/auth/index/creds_and_folder_present/server_error") do
          visit(gdrive_auth_path)
          expect(page).to have_content("server error")
        end
      end
    end
  end

  context "when saved credentials are present but no folder" do
    let!(:gdrive_config) { create(:gdrive_config) }

    it_behaves_like "need to connect"
  end

  context "when no saved credentials are present" do
    let!(:gdrive_config) { create(:gdrive_config) }

    it_behaves_like "need to connect"
  end

  context "when saved credentials are present but invalid" do
    let!(:gdrive_config) { create(:gdrive_config) }

    scenario "it shows need to re-authenticate" do

    end
  end
end
