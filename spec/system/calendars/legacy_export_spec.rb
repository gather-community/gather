# frozen_string_literal: true

require "rails_helper"

describe "calendar export" do
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { "mYfEv68-_HG4_lrfGGre" }
  let(:signature) { Calendars::Exports::LegacyIcalGenerator::UID_SIGNATURE }
  let!(:user) { create(:user, calendar_token: user_token) }
  let(:communityB) { create(:community) }

  before do
    Defaults.community.update!(calendar_token: cmty_token)
  end

  describe "show" do
    context "with user subdomain" do
      before do
        use_user_subdomain(user)
      end

      describe "general" do
        let!(:meal) { create(:meal) }
        let(:ical_code) do
          "BEGIN:VCALENDAR\r VERSION:2.0\r PRODID:icalendar-ruby\r CALSCALE:GREGORIAN\r METHOD:PUBLISH"
        end

        scenario "happy path (personalized)" do
          visit("/calendars/exports/all-meals/#{user_token}.ics")
          expect(page).to have_content(ical_code)
          # Ensure correct subdomain for links (not https b/c test mode)
          expect(page).to have_content("http://#{user.subdomain}.#{Settings.url.host}")
        end

        scenario "happy path (not personalized)" do
          visit("/calendars/exports/all-meals/+#{cmty_token}.ics")
          expect(page).to have_content(ical_code)
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

        scenario "gen 1 legacy URL" do
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
end
