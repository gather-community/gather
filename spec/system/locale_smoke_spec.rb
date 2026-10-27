# frozen_string_literal: true

require "rails_helper"

# Visits the main page of each module in every finished locale (Gather::Locales::TRANSLATED), as an admin
# whose browser asks for that locale. A missing translation raises in tests, so a page that renders has all
# its keys. Outside English, the page also mustn't contain common English UI words, which catch text that
# was never put through I18n.
describe "every module in every locale" do
  pages = {
    "meals" => :meals_path, "meal formulas" => :meals_formulas_path, "meal types" => :meals_types_path,
    "meal roles" => :meals_roles_path, "work signups" => :work_shifts_path, "work jobs" => :work_jobs_path,
    "work periods" => :work_periods_path, "work report" => :work_report_path, "calendars" => :calendars_path,
    "calendar protocols" => :calendars_protocols_path, "directory" => :users_path,
    "households" => :households_path, "birthdays" => :people_birthdays_path,
    "member types" => :people_member_types_path, "groups" => :groups_groups_path, "roles" => :roles_path,
    "domains" => :domains_path, "wiki" => :wiki_pages_path, "accounts" => :accounts_path,
    "notification settings" => :notification_preferences_path,
    "meal" => -> { meal_path(meal) }
  }

  # Whole words that would only appear in untranslated UI text. Test data is named so it doesn't use them.
  english_words = %w[the and your with Save Cancel Edit Delete Create Search Settings Upcoming Members
    Show None Name Entrees entrees Kids kids]
  # Words from that list that are also correct in another language, e.g. German "Name".
  same_in_locale = {de: %w[Name]}

  let(:admin) { create(:admin, first_name: "Kim", last_name: "Lee") }
  let(:meal) { create(:meal, :with_menu, title: "Ragout", entrees: "Ragout", kids: "Pasta", notes: "Merci") }

  before do
    create(:wiki_page, community: admin.community, role: "home", title: "Wiki", content: "Wiki")
    use_user_subdomain(admin)
    login_as(admin, scope: :user)
  end

  Gather::Locales::TRANSLATED.each do |locale|
    context locale.to_s do
      before do
        create(:feature_flag, name: Gather::Locales::FEATURE_FLAG, interface: "user").users << admin
        page.driver.header("Accept-Language", locale.to_s)
      end

      pages.each do |name, path|
        scenario name do
          visit(path.is_a?(Proc) ? instance_exec(&path) : send(path))
          expect(page).to have_css("html[lang='#{locale}']")
          expect(page).not_to have_css(".translation_missing")
          next if locale == :en
          english = (english_words - same_in_locale.fetch(locale, [])).select { |word| page.text.match?(/\b#{word}\b/) }
          expect(english).to be_empty, "#{name} in #{locale} has English words: #{english.join(", ")}"
        end
      end
    end
  end
end
