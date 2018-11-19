# frozen_string_literal: true

require "rails_helper"

feature "calendar export" do
  let(:token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:signature) { Calendars::Exports::IcalGenerator::UID_SIGNATURE }
  let!(:user) { create(:user, calendar_token: token) }

  describe "index" do
    before do
      login_as(user, scope: :user)
    end

    scenario do
      visit("/calendars/exports")
      click_link("All Meals")
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
      click_link("All Meals")
      expect(page).to have_content("BEGIN:VCALENDAR")
    end
  end

  describe "show" do
    context "with user subdomain" do
      around { |ex| with_user_home_subdomain(user) { ex.run } }

      describe "general" do
        let!(:meal) { create(:meal) }

        scenario "happy path" do
          visit("/calendars/exports/all-meals/#{token}.ics")
          expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
            "CALSCALE:GREGORIAN METHOD:PUBLISH")
          # Ensure correct subdomain for links (not https b/c test mode)
          expect(page).to have_content("http://#{user.subdomain}.#{Settings.url.host}")
        end

        scenario "bad calendar type" do
          visit("/calendars/exports/pants/#{token}.ics")
          expect(page).to have_content("Invalid calendar type")
        end

        scenario "bad token" do
          visit("/calendars/exports/meals/z8TfwETMhx93t655keKA.ics")
          expect(page).to have_http_status(403)
        end

        scenario "legacy URL" do
          visit("/calendars/all-meals/#{token}.ics")
          expect_calendar_name("All Meals")
        end
      end

      describe "meals" do
        let(:communityB) { create(:community) }
        let!(:resource) { create(:resource, name: "Dining Room") }
        let!(:meal1) do
          create(:meal, :with_menu, title: "Meal1", head_cook: user,
                                    served_at: Time.current + 1.day, resources: [resource])
        end
        let!(:meal2) do
          create(:meal, :with_menu, title: "Meal2", served_at: Time.current + 2.days)
        end
        let!(:meal3) do
          create(:meal, :with_menu, title: "Other Cmty Meal", community: communityB,
                                    served_at: Time.current + 3.days,
                                    communities: [meal1.community, communityB])
        end
        let!(:signup) { create(:signup, meal: meal1, household: user.household, adult_meat: 2) }

        scenario "your meals" do
          visit("/calendars/exports/meals/#{token}.ics")
          expect_calendar_name("Meals You're Attending")
          expect_events(
            description: /By #{user.name}\s+2 diners from your household/,
            summary: "Meal1",
            location: "#{user.community_abbrv} Dining Room"
          )
          expect(page).not_to have_content("Meal2")
          expect(page).not_to have_content("Other Cmty Meal")
        end

        scenario "community meals" do
          visit("/calendars/exports/community-meals/#{token}.ics")
          expect_calendar_name("#{user.community.name} Meals")
          expect_events({
            summary: "Meal1"
          },
            summary: "Meal2")
          expect(page).not_to have_content("Other Cmty Meal")
        end

        scenario "all meals" do
          visit("/calendars/exports/all-meals/#{token}.ics")
          expect_calendar_name("All Meals")
          expect_events({
            summary: "Meal1"
          }, {
            summary: "Meal2"
          },
            summary: "Other Cmty Meal")
        end
      end

      describe "reservations" do
        let(:resource) { create(:resource, name: "Fun Room") }
        let!(:reservation1) do
          create(:reservation, starts_at: Time.current + 1.hour, resource: resource,
                               reserver: user, name: "Games")
        end
        let!(:reservation2) { create(:reservation, starts_at: Time.current + 2.hours, name: "Dance") }

        scenario "your reservations" do
          visit("/calendars/exports/your-reservations/#{token}.ics")
          expect_calendar_name("Your Reservations")
          expect_events(
            summary: "Games (#{user.name})",
            location: "Fun Room",
            description: %r{http://.+/reservations/}
          )
          expect(page).not_to have_content("Dance")
        end

        scenario "community reservations" do
          visit("/calendars/exports/community-reservations/#{token}.ics")
          expect_calendar_name("Reservations")
          expect_events({
            summary: "Games (#{user.name})"
          },
            summary: "Dance (#{reservation2.reserver.name})")
        end
      end

      describe "shifts" do
        let(:meal1_time) { Time.current.midnight + 3.days + 18.hours }
        let(:meal2_time) { Time.current.midnight + 7.days + 18.hours }
        let!(:meal1) do
          create(:meal, :with_menu, title: "Figs", served_at: meal1_time, head_cook: user)
        end
        let!(:meal2) { create(:meal, served_at: meal1_time) }

        context "when using work system" do
          let(:period) { create(:work_period, starts_on: Time.current) }
          let!(:job1) do
            create(:work_job, title: "Head Cook", period: period, time_type: "date_time",
                              description: "Cook all the things",
                              shift_count: 2, shift_times: [meal1_time, meal2_time])
          end
          let!(:job2) do
            create(:work_job, title: "Frumbler", period: period, time_type: "date_only",
                              description: "A very silly job.",
                              shift_count: 1, shift_times: [Time.current.midnight + 2.days])
          end

          before do
            # Associate meals with appropriate shifts.
            job1.shifts[0].update!(meal_id: meal1.id)
            job1.shifts[1].update!(meal_id: meal2.id)

            # Assign meal shift and other job shift to user.
            job1.shifts[0].assignments.create!(user: user)
            job2.shifts[0].assignments.create!(user: user)
          end

          scenario "includes all shifts" do
            visit("/calendars/exports/your-jobs/#{token}.ics")
            expect_calendar_name("Your Jobs")
            expect_events({
              summary: "Frumbler",
              location: nil,
              description: %r{A very silly job\.\s+\n http://.+/work/signups/}
            },
              uid: "#{signature}_Shift_#{job1.shifts[0].id}",
              summary: "Head Cook: Figs",
              location: meal1.resources[0].name,
              description: %r{Cook all the things\s+\n http://.+/work/signups/})
          end
        end

        context "when not using work system" do
          let!(:assignment) { meal1.assignments[0] }

          scenario "uses meal assignments only" do
            visit("/calendars/exports/your-jobs/#{token}.ics")
            expect_calendar_name("Your Jobs")
            expect_events(
              uid: "#{signature}_Assignment_#{assignment.id}",
              summary: "Head Cook: Figs",
              location: meal1.resources[0].name,
              description: %r{http://.+/meals/}
            )
          end
        end
      end
    end

    context "with apex subdomain" do
      scenario "your meals" do
        visit("/calendars/exports/meals/#{token}.ics")
        expect(page).to have_content("Meals You're Attending")

        # We don't want to redirect when fetching ICS in case some clients don't support that.
        expect(current_url).not_to match(user.community.slug)
      end
    end
  end

  def expect_calendar_name(name)
    expect(page.body).to match(/X-WR-CALNAME:#{name}/)
  end

  def expect_events(*events)
    blocks = page.body.scan(/BEGIN:VEVENT.+?END:VEVENT/m)
    expect(blocks.size).to eq(events.size)
    events.each_with_index do |event, i|
      event.each do |key, value|
        if value.nil?
          expect(blocks[i]).not_to match(/^#{key.to_s.dasherize.upcase}:/)
        else
          value = value.is_a?(Regexp) ? value : Regexp.quote(value)
          expect(blocks[i]).to match(/^#{key.to_s.dasherize.upcase}:#{value}/)
        end
      end
    end
  end

  def token_from_url
    find("a", text: "All Meals")[:href].match(%r{/([A-Za-z0-9_\-]{20})\.ics})[1]
  end
end
