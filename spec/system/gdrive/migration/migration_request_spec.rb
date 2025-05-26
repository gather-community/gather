# frozen_string_literal: true

require "rails_helper"

describe "gdrive migration request" do
  include_context "gdrive"

  let!(:migration_request) { create(:gdrive_migration_request) }
  let!(:file) do
    create(:gdrive_migration_file, operation: migration_request.operation,
      owner: migration_request.google_email)
  end

  before do
    use_subdomain(migration_request.operation.community.slug)
  end

  scenario "happy path" do
    page.driver.header('User-Agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_7_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/137.0.7151.34 Mobile/15E148 Safari/604.1')
    visit(gdrive_migration_request_path(token: migration_request.token))
    expect(page).to have_content("It looks like you're using a mobile device.")

    page.driver.header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36')
    visit(gdrive_migration_request_path(token: migration_request.token))
    expect(page).to have_content("Introduction")
    click_on("Yes, I am ready to help!")
    expect(page).to have_content("Step 1:")
    click_on("Next >")
    expect(page).to have_content("Step 2:")
    click_on("Next >")
    expect(page).to have_content("Step 3:")
    click_on("Next >")
    expect(page).to have_content("Step 4:")

    click_on("Step 2")
    expect(page).to have_content("Step 2:")
    click_on("Next >")
    expect(page).to have_content("Step 3:")
    click_on("Next >")
    expect(page).to have_content("Step 4:")
    click_on("Next >")
    expect(page).to have_content("Step 5:")

    click_on("Step 2")
    expect(page).to have_content("Step 2:")
    click_on("Next >")
    expect(page).to have_content("Step 3:")
    click_on("Next >")
    expect(page).to have_content("Step 4:")
    click_on("Next >")
    expect(page).to have_content("Step 5:")
    click_on("Finish")
    expect(page).to have_content("All Done")

    visit(gdrive_migration_request_path(token: migration_request.token))
    expect(page).to have_content("Introduction")
    click_on("Yes, I am ready to help!")
    expect(page).to have_content("Step 1:")
    click_on("Next >")
    expect(page).to have_content("Step 2:")
    click_on("Next >")
    expect(page).to have_content("Step 3:")
    click_on("Next >")
    expect(page).to have_content("Step 4:")
    click_on("Next >")
    expect(page).to have_content("Step 5:")
    click_on("< Previous")
    expect(page).to have_content("Step 4:")
    click_on("< Previous")
    expect(page).to have_content("Step 3:")
    click_on("< Previous")
    expect(page).to have_content("Step 2:")
    click_on("< Previous")
    expect(page).to have_content("Step 1:")
    click_on("< Previous")
    expect(page).to have_content("Introduction")

    click_on("opt out")
    expect(page).to have_content("File Selection Opt Out")
    click_on("go back")
    expect(page).to have_content("Introduction")
    click_on("opt out")
    expect(page).to have_content("File Selection Opt Out")
    fill_in("Opt Out Reason", with: "testing")
    click_on("Opt Out")
    expect(page).to have_content("You have opted out")

    click_on("clicking here")
    expect(page).to have_content("Introduction")
  end
end
