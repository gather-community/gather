# frozen_string_literal: true

require "rails_helper"

describe "gdrive migration dashboard files", js: true do
  include_context "gdrive"

  let!(:actor) { create(:admin) }
  let!(:config) { create(:gdrive_config) }
  let!(:operation) { create(:gdrive_migration_operation) }
  let!(:scan) { create(:gdrive_migration_scan, operation: operation, status: "complete") }
  let!(:file1) { create(:gdrive_migration_file, operation: operation, owner: "alice@example.com", status: "pending", name: "Alice File") }
  let!(:file2) { create(:gdrive_migration_file, operation: operation, owner: "bob@example.com", status: "transferred", name: "Bob File") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "owner lens" do
    visit(gdrive_migration_dashboard_files_path)
    expect(page).to have_content("Alice File")
    expect(page).to have_content("Bob File")

    select_lens(:owner, "alice@example.com")
    expect(page).to have_content("Alice File")
    expect(page).not_to have_content("Bob File")

    select_lens(:owner, "Any Owner")
    expect(page).to have_content("Alice File")
    expect(page).to have_content("Bob File")
  end

  scenario "status lens" do
    visit(gdrive_migration_dashboard_files_path)
    expect(page).to have_content("Alice File")
    expect(page).to have_content("Bob File")

    select_lens(:status, "Pending")
    expect(page).to have_content("Alice File")
    expect(page).not_to have_content("Bob File")

    select_lens(:status, "Transferred")
    expect(page).not_to have_content("Alice File")
    expect(page).to have_content("Bob File")

    select_lens(:status, "Any Status")
    expect(page).to have_content("Alice File")
    expect(page).to have_content("Bob File")
  end
end
