# frozen_string_literal: true

require "rails_helper"

describe "wiki search", js: true do
  let(:actor) { create(:user) }
  let(:community) { Defaults.community }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "path 1: searching via lens on a wiki page", search: Wiki::Page do
    let!(:wiki_page) { create(:wiki_page, community: community, title: "Solar Panel Guide") }

    before do
      Wiki::Page.__elasticsearch__.refresh_index!
    end

    scenario "lens search navigates to search page and shows wiki results" do
      visit(wiki_page_path(slug: wiki_page.slug))
      expect(page).to have_css(".lens-bar")

      fill_in_lens(:search, "solar")

      expect(page).to have_current_path(/#{Regexp.escape(wiki_search_path)}/)
      expect(page).to have_link("Solar Panel Guide", href: wiki_page_path(slug: wiki_page.slug))
    end
  end

  context "path 2: searching via lens on the GDrive page" do
    let!(:config) { create(:gdrive_config) }

    scenario "lens search navigates to the search page" do
      visit(gdrive_home_path)
      expect(page).to have_css(".lens-bar")

      fill_in_lens(:search, "budget")

      expect(page).to have_current_path(/#{Regexp.escape(wiki_search_path)}/)
      expect(page).to have_content("Search")
    end
  end

  context "path 3: navigating directly to the Search tab and searching", search: Wiki::Page do
    let!(:wiki_page) { create(:wiki_page, community: community, title: "Compost Bins") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    scenario "clicking Search tab, typing in body form, and seeing results" do
      visit(wiki_page_path(slug: wiki_page.slug))
      click_link("Search")

      expect(page).to have_current_path(wiki_search_path)
      expect(page).to have_css(".search-input-group")

      fill_in("search", with: "compost")
      find(".search-body-form .btn-default").click

      expect(page).to have_current_path(/#{Regexp.escape(wiki_search_path)}/)
      expect(page).to have_link("Compost Bins", href: wiki_page_path(slug: wiki_page.slug))
    end
  end
end
