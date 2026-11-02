# frozen_string_literal: true

require "rails_helper"

describe "language menu", js: true do
  let(:user) { create(:user) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  scenario "without the feature flag" do
    visit(users_path)
    expect(page).to have_css("#global-footer")
    expect(page).not_to have_content("Change Language")
    expect(page).not_to have_css("#language-menu-select", visible: :all)
  end

  context "with the feature flag" do
    before { create(:feature_flag, name: "i18n", status: true) }

    scenario "choosing a language, then going back to the browser's" do
      visit(users_path)
      expect(page).to have_css("html[lang='en']")
      expect(page).not_to have_select("language-menu-select")

      click_link("Change Language")
      expect(page).not_to have_link("Change Language")
      expect(page).to have_select("language-menu-select", selected: "Browser Default", options: [
        "Browser Default", "Deutsch", "English", "Español", "Français", "Français (Canada)", "Italiano",
        "Nederlands", "Norsk bokmål", "Suomi", "Svenska"
      ])

      select("Deutsch", from: "language-menu-select")
      expect(page).to have_css("html[lang='de']")
      expect(page).to have_link("Sprache ändern")
      expect(page.driver.browser.manage.cookie_named(Gather::Locales::COOKIE)[:value]).to eq("de")

      # The menu shows the choice when it's opened again.
      click_link("Sprache ändern")
      expect(page).to have_select("language-menu-select", selected: "Deutsch")

      # The browser asks for English, so the page goes back to English once the cookie is gone.
      select("Sprache des Browsers", from: "language-menu-select")
      expect(page).to have_css("html[lang='en']")
      expect(page).to have_link("Change Language")
      expect(page.driver.browser.manage.all_cookies.pluck(:name)).not_to include(Gather::Locales::COOKIE)
    end
  end
end
