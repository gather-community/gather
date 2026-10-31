# frozen_string_literal: true

require "rails_helper"

# The settings that decide which language Gather emails people in: a person's own choice on their profile,
# their community's default, and the language chosen when a community signs up. See Gather::Locales.for_user.
describe "email language" do
  let(:community) { Defaults.community }

  context "with other languages turned on" do
    before { create(:feature_flag, name: "i18n", status: true) }

    describe "profile" do
      let(:user) { create(:user) }

      before do
        use_user_subdomain(user)
        login_as(user, scope: :user)
      end

      scenario "choosing a language, then going back to the community's" do
        visit(edit_user_path(user))
        expect(page).to have_select("Email Language", with_options: ["Community default (English)"])
        select("Deutsch", from: "Email Language")
        click_button("Save")
        expect(page).to have_content("Profile updated successfully")
        expect(user.reload.locale).to eq("de")

        visit(edit_user_path(user))
        select("Community default (English)", from: "Email Language")
        click_button("Save")
        expect(user.reload.locale).to be_nil
      end
    end

    describe "community settings" do
      let(:admin) { create(:admin) }

      before do
        use_user_subdomain(admin)
        login_as(admin, scope: :user)
      end

      scenario "setting the community's default language" do
        visit("/admin/settings/community")
        expect(page).to have_select("Default Language", selected: "English")
        select("Français (Canada)", from: "Default Language")
        click_button("Save")
        expect(page).to have_content("Settings updated successfully")
        expect(community.reload.settings.locale).to eq("fr-CA")
      end
    end

    describe "community signup" do
      before do
        allow_any_instance_of(Communities::SignupsController).to receive(:verify_hcaptcha).and_return(true)
      end

      scenario "the language starts as the page's and becomes the new community's default" do
        page.driver.header("Accept-Language", "nl")
        visit(new_communities_signup_path)
        expect(page).to have_select("communities_signup[locale]", selected: "Nederlands")

        page.driver.header("Accept-Language", "en")
        visit(new_communities_signup_path)
        expect(page).to have_select("Language", selected: "English")
        fill_in_signup
        select("Svenska", from: "Language")
        click_button("Submit Application")
        expect(page).to have_title("Application Submitted")
        expect(Communities::Signup.last.locale).to eq("sv")
      end
    end
  end

  context "with other languages off" do
    let(:user) { create(:admin) }

    before do
      use_user_subdomain(user)
      login_as(user, scope: :user)
    end

    scenario "no language settings are shown" do
      visit(edit_user_path(user))
      expect(page).to have_field("First Name")
      expect(page).not_to have_field("Email Language")

      visit("/admin/settings/community")
      expect(page).to have_field("Time Zone")
      expect(page).not_to have_field("Default Language")
    end

    scenario "a signup is in English" do
      allow_any_instance_of(Communities::SignupsController).to receive(:verify_hcaptcha).and_return(true)
      visit(new_communities_signup_path)
      expect(page).not_to have_field("Language")
      fill_in_signup
      click_button("Submit Application")
      expect(page).to have_title("Application Submitted")
      expect(Communities::Signup.last.locale).to eq("en")
    end
  end

  def fill_in_signup
    fill_in("First Name", with: "Alice")
    fill_in("Last Name", with: "Smith")
    fill_in("Email Address", with: "alice@example.com")
    fill_in("Community Name", with: "Sunrise Cohousing")
    fill_in("Community URL", with: "sunrise-coho")
    select("United States", from: "Country")
    select("Eastern Time (US & Canada)", from: "Time Zone")
    fill_in("About Your Community", with: "We are a cohousing community. https://sunrise.example.com")
  end
end
