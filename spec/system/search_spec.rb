# frozen_string_literal: true

require "rails_helper"

describe "search", js: true do
  let(:actor) { create(:user) }
  let(:community) { Defaults.community }

  before do
    create(:feature_flag, name: "search", status: true)
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

      fill_in("search-body-input", with: "solar")
      find(".search-body-form button[type=submit]").click

      expect(page).to have_current_path(/#{Regexp.escape(search_path)}/)
      expect(page).to have_link("Solar Panel Guide", href: wiki_page_path(slug: wiki_page.slug))
      expect(page).to have_content("Wiki")
    end

    scenario "searching from the box in the top nav" do
      visit(wiki_pages_path)
      within(".nav-search-form") do
        fill_in("search", with: "solar")
        find("input[name=search]").send_keys(:enter)
      end
      expect(page).to have_link("Solar Panel Guide", href: wiki_page_path(slug: wiki_page.slug))
    end
  end

  describe "type filters" do
    scenario "unchecking one type leaves the others checked" do
      visit(search_path(search: "test"))
      uncheck("Wiki Pages")

      expect(page).to have_current_path(/types=/)
      expect(page).to have_unchecked_field("Wiki Pages")
      expect(page).to have_checked_field("Meals")
      expect(page).to have_checked_field("Transactions")
    end

    scenario "deselect all and select all" do
      visit(search_path(search: "test"))
      click_on("Deselect All")

      expect(page).to have_content("Select at least one type to search.")
      expect(page).to have_unchecked_field("Meals")
      expect(page).to have_unchecked_field("Wiki Pages")

      click_on("Select All")
      expect(page).to have_checked_field("Meals")
      expect(page).to have_checked_field("Wiki Pages")
      expect(page).not_to have_current_path(/types=/)
    end

    context "without a Google Drive connection" do
      scenario "there's one Filter section and no Drive column" do
        visit(search_path(search: "test"))
        expect(page).to have_css(".search-sidebar h3", text: "Filter")
        expect(page).to have_checked_field("Meals")
        expect(page).not_to have_field("Google Docs")
        expect(page).not_to have_css("#drive-pane")
      end
    end

    context "with a Google Drive connection" do
      let!(:config) { create(:gdrive_config, community: community) }

      scenario "Gather and Google Drive sections, each in alphabetical order" do
        visit(search_path(search: "test"))
        headings = all(".search-sidebar h3").map(&:text)
        expect(headings).to eq(["Gather", "Google Drive"])
        drive_labels = all(".search-sidebar .checkbox-list")[1].all("label").map(&:text).map(&:strip)
        expect(drive_labels).to eq(["Folders", "Google Docs", "Google Sheets", "Google Slides",
          "Other Files", "PDFs"])
        gather_labels = all(".search-sidebar .checkbox-list")[0].all("label").map(&:text).map(&:strip)
        expect(gather_labels).to eq(gather_labels.sort)
      end

      scenario "unchecking one Drive type keeps the Drive column; unchecking them all hides it" do
        visit(search_path(search: "test"))
        uncheck("PDFs")
        expect(page).to have_unchecked_field("PDFs")
        expect(page).to have_css("#drive-pane")

        ["Folders", "Google Docs", "Google Sheets", "Google Slides", "Other Files"].each do |label|
          uncheck(label)
          expect(page).to have_unchecked_field(label)
        end
        expect(page).not_to have_css("#drive-pane")
        expect(page).to have_checked_field("Meals")
      end
    end
  end

  describe "pagination", search: Wiki::Page do
    before do
      12.times { |i| create(:wiki_page, community: community, title: "Compost tip #{i + 1}") }
      Wiki::Page.__elasticsearch__.refresh_index!
    end

    scenario "shows 10 results, the full count, and loads more" do
      visit(search_path(search: "compost"))
      expect(page).to have_content("Results (12)") # "Gather" only appears alongside Drive
      expect(page).to have_css(".search-result-list li", count: 10)

      click_on("More results")
      expect(page).to have_css(".search-result-list li", count: 12)
      expect(page).not_to have_link("More results")
    end
  end

  describe "wiki search box", search: Wiki::Page do
    let!(:wiki_page) { create(:wiki_page, community: community, title: "Compost Guide") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    scenario "searches with only wiki pages checked" do
      visit(wiki_page_path(slug: wiki_page.slug))
      within(".lens-bar") do
        fill_in("search", with: "compost")
        find("input[name=search]").send_keys(:enter)
      end

      expect(page).to have_current_path(/types=wiki_page/)
      expect(page).to have_checked_field("Wiki Pages")
      expect(page).to have_unchecked_field("Meals")
      expect(page).to have_link("Compost Guide")
    end

    scenario "isn't shown when search is turned off" do
      FeatureFlag.find_by(name: "search").update!(status: false)
      visit(wiki_page_path(slug: wiki_page.slug))
      expect(page).to have_content("Compost Guide")
      expect(page).not_to have_css(".lens-bar input[name=search]")
    end
  end

  describe "search tips modal" do
    scenario "clicking search tips link shows the modal" do
      visit(search_path)
      find(".search-tips-button").click
      expect(page).to have_css("#search-tips-modal.in", wait: 3)
      expect(page).to have_content("Basic search")
    end
  end
end
