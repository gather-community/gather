# frozen_string_literal: true

require "rails_helper"

feature "calendar export" do
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { "mYfEv68-_HG4_lrfGGre" }
  let(:signature) { Calendars::Exports::IcalGenerator::UID_SIGNATURE }
  let!(:user) { create(:user, calendar_token: user_token) }
  let(:communityB) { create(:community) }

  before do
    Defaults.community.update!(calendar_token: cmty_token)
  end

  describe "index" do
    before do
      login_as(user, scope: :user)
    end

    scenario do
      visit("/calendars/exports")
      within(".personalized-links") { click_link("All Meals") }
      expect(page).to have_content("BEGIN:VCALENDAR")
    end
  end

  describe "reset_token" do
    before do
      login_as(user, scope: :user)
    end

    scenario do
      visit("/calendars/exports")
      old_token = token_from_url
      click_link("click here to reset your secret token")
      expect(page).to have_content("Token reset successfully")
      expect(token_from_url).not_to eq(old_token)
      within(".personalized-links") { click_link("All Meals") }
      expect(page).to have_content("BEGIN:VCALENDAR")
    end
  end

  describe "show" do
    context "with user subdomain" do
      around { |ex| with_user_home_subdomain(user) { ex.run } }

      describe "general" do
        let!(:meal) { create(:meal) }

        scenario "happy path (personalized)" do
          visit("/calendars/exports/all-meals/#{user_token}.ics")
          expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
            "CALSCALE:GREGORIAN METHOD:PUBLISH")
          # Ensure correct subdomain for links (not https b/c test mode)
          expect(page).to have_content("http://#{user.subdomain}.#{Settings.url.host}")
        end

        scenario "happy path (not personalized)" do
          visit("/calendars/exports/all-meals/+#{cmty_token}.ics")
          expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
            "CALSCALE:GREGORIAN METHOD:PUBLISH")
        end

        scenario "bad calendar type" do
          visit("/calendars/exports/pants/#{user_token}.ics")
          expect(page).to have_content("Invalid calendar type")
        end

        scenario "bad user token" do
          visit("/calendars/exports/all-meals/totalgarbageofatoken.ics")
          expect(page).to have_http_status(401)
        end

        scenario "bad community token" do
          expect do
            visit("/calendars/exports/all-meals/+totalgarbageofatoken.ics")
          end.to raise_error(Pundit::NotAuthorizedError) # Error reaches here b/c not a JS test.
        end

        scenario "legacy URL" do
          visit("/calendars/meals/#{user_token}.ics")
          expect(page).to have_http_status(200)
          expect(page).to have_content("Meals You're Attending")
        end
      end
    end

    context "with apex subdomain" do
      scenario "your meals" do
        visit("/calendars/exports/meals/#{user_token}.ics")
        expect(page).to have_content("Meals You're Attending")

        # We don't want to redirect when fetching ICS in case some clients don't support that.
        expect(current_url).not_to match(user.community.slug)
      end
    end
  end

  def token_from_url
    within(".personalized-links") do
      find("a", text: "All Meals")[:href].match(%r{/([A-Za-z0-9_\-]{20})\.ics})[1]
    end
  end
end
