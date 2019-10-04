require "rails_helper"

feature "pages", js: true do
  let(:actor) { create(:user, first_name: "Jane", last_name: "Doe") }
  let(:other_community) { create(:community, cluster: actor.cluster) }
  let!(:decoy_page) { create(:wiki_page, community: other_community, title: "Another Page") }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit("/wiki")
    click_on("Sample Page")
    expect(page).to have_content("This is a sample wiki page.")

    click_main_nav("Wiki")
    expect(page).to have_content("This is your wiki home page!")

    click_link("Edit")
    fill_in("Content", with: "Here is a link to [[Another Page]]")
    click_button("Save")
    expect(page).to have_content(/Page revised on .+ by Jane Doe/)

    click_on("Another Page")
    expect(page).to have_content("There is no wiki page named 'Another Page'")

    # Showing preview should not save page.
    expect do
      fill_in("Content", with: "Version one")
      click_on("Preview")
      expect(page).to have_content("This is a preview")
      expect(page).to have_css(".wiki-content", text: "Version one")
    end.to change { Wiki::Page.count }.by(0)

    click_button("Save")

    expect(page).not_to have_content("This is a preview")
    expect(page).to have_content("Version one")

    click_on("Edit")
    click_on("Cancel")
    expect(page).not_to have_content("Edit Wiki Page")
    expect(page).to have_content("Version one")

    click_on("Edit")
    fill_in("Content", with: "Version two")
    click_button("Save")

    click_on("History")
    expect(page).to have_css("td.updater", text: "Jane Doe")
    click_on("Compare Selected")
    expect(page).to have_css("del", text: "Version one")
    expect(page).to have_css("ins", text: "Version two")

    click_on("Return to Page")
    expect(page).not_to have_content("Wiki Compare")
    expect(page).to have_content("Version two")

    click_on("New Wiki Page")
    fill_in("Title", with: "Boring Page")
    fill_in("Content", with: "apple **banana** cherry")
    click_button("Save")
    expect(page).to have_content("apple banana cherry")

    click_on("Wiki Page Listing")
    expect(page).to have_css("li", text: "Another Page", count: 1) # Ensure no decoy
    expect(page).to have_css("li", text: "Boring Page")

    click_on("Boring Page")
    accept_confirm { click_on("Delete") }
    expect_success
    expect(page).to have_content("Here is a link to Another Page")
  end

  scenario "previewing edit should not save changes" do
    visit("/wiki")
    expect(page).to have_content("This is your wiki home page!")
    click_on("Edit")
    fill_in("Content", with: "New content")
    click_on("Preview")
    expect(page).to have_content("This is a preview")
    click_on("Cancel")
    visit("/wiki")
    expect(page).not_to have_content("New content")
  end

  scenario "validation error" do
    visit("/wiki/new")

    # Should not render preview
    fill_in("Content", with: "**bold text**")
    click_on("Preview")
    expect(page).to have_css(".wiki_page_title .error", text: "Can't be blank")
    expect(page).not_to have_css("b", text: "bold text")
  end

  context "with data source", :vcr do
    let(:actor) { create(:admin) }

    before do
      visit("/wiki")
      click_on("New Wiki Page")
      fill_in("Title", with: "A Page")
      fill_in("Content", with: "The Description: {{description}}")
      fill_in("Data Source", with: "http://json-schema.org/example/geo.json")
      click_button("Save")
    end

    scenario "with valid data" do
      expect(page).to have_content("The Description: A geographical coordinate")
    end

    scenario "with invalid data" do
      expect(page).to have_alert("There was a problem fetching data for this page (Invalid JSON)")
      expect(page).not_to have_content("The Description:")
    end
  end

  context "as superadmin from other cluster" do
    let(:outside_community) { ActsAsTenant.with_tenant(create(:cluster)) { create(:community) } }
    let(:actor) do
      create(:super_admin, community: outside_community, first_name: "Jane", last_name: "Doe")
    end

    scenario "does not record updater" do
      visit("/wiki")
      expect(page).not_to have_content(/Page revised on .+ by Jane Doe/)
      click_link("Edit")
      fill_in("Content", with: "Filth")
      click_button("Save")
      expect(page).not_to have_content(/Page revised on .+ by Jane Doe/)
      click_link("History")
      expect(page).not_to have_css("td.updater", text: "Jane Doe")
    end
  end
end
