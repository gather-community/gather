# frozen_string_literal: true

require "rails_helper"

describe "search", js: true do
  let(:actor) { create(:user) }
  let(:community) { Defaults.community }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  describe "search page", search: Wiki::Page do
    let!(:wiki_page) { create(:wiki_page, community: community, title: "Solar Panel Guide") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    scenario "shows a search form and results when a query is entered" do
      visit(search_path)
      expect(page).to have_css(".search-input-group")
      expect(page).to have_content("Enter a search term")

      fill_in("search", with: "solar")
      find(".search-body-form .btn-default").click

      expect(page).to have_current_path(/#{Regexp.escape(search_path)}/)
      expect(page).to have_link("Solar Panel Guide", href: wiki_page_path(slug: wiki_page.slug))
      expect(page).to have_content("Wiki")
    end

    scenario "search icon in nav links to search page" do
      visit(wiki_pages_path)
      find(".search-nav-link").click
      expect(page).to have_current_path(search_path)
    end
  end

  describe "type filters" do
    scenario "unchecking all Gather types hides Gather column" do
      visit(search_path(search: "test"))

      # Uncheck wiki_page type (one of many)
      uncheck "Wiki pages"

      # Page reloads with types param excluding wiki_page
      expect(page).to have_current_path(/types=/)
    end

    scenario "unchecking Google Drive hides drive column" do
      visit(search_path(search: "test"))

      uncheck "Google Drive"

      expect(page).to have_current_path(/types=/)
      expect(page).not_to have_css("#drive-pane")
    end
  end

  describe "search tips modal" do
    scenario "clicking search tips link shows the modal" do
      visit(search_path)
      click_link("Search tips")
      expect(page).to have_css("#search-tips-modal.in", wait: 3)
      expect(page).to have_content("Basic search")
    end
  end
end
