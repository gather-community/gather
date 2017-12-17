require "rails_helper"

feature "pages", js: true do
  let(:actor) { create(:user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit("/wiki")
    expect(page).to have_content("This is your wiki home page!")

    click_link("Edit")
    fill_in("Content", with: "Here is a link to [[Another Page]]")
    click_on("Update Page")

    click_on("Another Page")
    expect(page).to have_content("There is no wiki page named 'Another Page'")

    fill_in("Content", with: "Version one")
    click_on("Preview")

    expect(page).to have_content("This is a preview")
    expect(page).to have_css(".wiki-content", text: "Version one")
    click_on("Create Page")

    expect(page).not_to have_content("This is a preview")
    expect(page).to have_content("Version one")

    click_on("Edit")
    click_on("Cancel")
    expect(page).not_to have_content("Edit Wiki Page")
    expect(page).to have_content("Version one")

    click_on("Edit")
    fill_in("Content", with: "Version two")
    click_on("Update Page")

    click_on("History")
    click_on("Compare Selected")
    expect(page).to have_css("del", text: "Version one")
    expect(page).to have_css("ins", text: "Version two")

    click_on("Return to Page")
    expect(page).not_to have_content("Wiki Compare")
    expect(page).to have_content("Version two")

    click_on("New Wiki Page")
    fill_in("Title", with: "Yet Another Page")
    fill_in("Content", with: "apple **banana** cherry")
    click_on("Create Page")
    expect(page).to have_content("apple banana cherry")

    click_on("Wiki Page Listing")
    expect(page).to have_css("li", text: "Another Page")
    expect(page).to have_css("li", text: "Yet Another Page")

    click_on("Yet Another Page")
    accept_confirm { click_on("Delete") }
    expect(page).to have_alert("Page deleted successfully.")
    expect(page).to have_content("Here is a link to Another Page")
  end
end
