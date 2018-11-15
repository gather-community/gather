# frozen_string_literal: true

require "rails_helper"

feature "calendar export" do
  let!(:user) { create(:user, calendar_token: "xyz") }

  describe "index" do
    before do
      login_as(user, scope: :user)
    end

    scenario do
      visit("/calendars")
      click_on("All Meals")
      expect(page).to have_content("BEGIN:VCALENDAR")
    end
  end

  describe "show" do
    context "with user subdomain" do
      around { |ex| with_user_home_subdomain(user) { ex.run } }

      describe "general" do
        let!(:meal) { create(:meal) }

        scenario "happy path" do
          visit("/calendars/all-meals/xyz.ics")
          expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
            "CALSCALE:GREGORIAN METHOD:PUBLISH")
          # Ensure correct subdomain for links (not https b/c test mode)
          expect(page).to have_content("http://#{user.subdomain}.#{Settings.url.host}")
        end

        scenario "bad calendar type" do
          visit("/calendars/pants/xyz.ics")
          expect(page).to have_content("Invalid calendar type")
        end

        scenario "bad token" do
          visit("/calendars/meals/xyzw.ics")
          expect(page).to have_http_status(403)
        end
      end

      describe "meals" do
        let(:communityB) { create(:community) }
        let!(:resource) { create(:resource, name: "Dining Room") }
        let!(:meal1) { create(:meal, :with_menu, title: "Meal1", head_cook: user, resources: [resource]) }
        let!(:meal2) { create(:meal, :with_menu, title: "Meal2") }
        let!(:meal3) do
          create(:meal, :with_menu, title: "Other Cmty Meal", community: communityB,
                                    communities: [meal1.community, communityB])
        end
        let!(:signup) { create(:signup, meal: meal1, household: user.household, adult_meat: 2) }

        scenario "your meals" do
          visit("/calendars/meals/xyz.ics")
          expect_pairs(
            x_wr_calname: "Meals You're Attending",
            description: /By #{user.name}\s+2 diners from your household/,
            summary: "Meal1",
            location: "#{user.community_abbrv} Dining Room"
          )
          expect(page).not_to have_content("Meal2")
          expect(page).not_to have_content("Other Cmty Meal")
        end

        scenario "community meals" do
          visit("/calendars/community-meals/xyz.ics")
          expect_pairs(
            x_wr_calname: "#{user.community.name} Meals",
            summary: "Meal2"
          )
          expect(page).not_to have_content("Other Cmty Meal")
        end

        scenario "all meals" do
          visit("/calendars/all-meals/xyz.ics")
          expect_pairs(
            x_wr_calname: "All Meals",
            summary: "Other Cmty Meal"
          )
        end

        scenario "jobs" do
          visit("/calendars/shifts/xyz.ics")
          expect_pairs(
            x_wr_calname: "Your Meal Jobs",
            summary: "Head Cook: Meal1",
            location: "#{user.community_abbrv} Dining Room",
            description: %r{http://.+/meals/}
          )
        end
      end

      describe "reservations" do
        let(:resource) { create(:resource, name: "Fun Room") }
        let!(:reservation1) { create(:reservation, resource: resource, reserver: user, name: "Games") }
        let!(:reservation2) { create(:reservation, name: "Dance") }

        scenario "your reservations" do
          visit("/calendars/your-reservations/xyz.ics")
          expect_pairs(
            x_wr_calname: "Your Reservations",
            summary: "Games (#{user.name})",
            location: "Fun Room",
            description: %r{http://.+/reservations/}
          )
          expect(page).not_to have_content("Dance")
        end

        scenario "reservations" do
          visit("/calendars/reservations/xyz.ics")
          expect_pairs(
            x_wr_calname: "Reservations",
            summary: "Dance (#{reservation2.reserver.name})"
          )
        end
      end
    end

    context "with apex subdomain" do
      scenario "your meals" do
        visit("/calendars/meals/xyz.ics")
        expect(page).to have_content("Meals You're Attending")

        # We don't want to redirect when fetching ICS in case some clients don't support that.
        expect(current_url).not_to match(user.community.slug)
      end
    end
  end

  def expect_pairs(hash)
    hash.each do |key, value|
      value = value.is_a?(Regexp) ? value : Regexp.quote(value)
      expect(page.body).to match(/#{key.to_s.dasherize.upcase}:#{value}/)
    end
  end
end
