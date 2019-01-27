# frozen_string_literal: true

require "rails_helper"

feature "calendar export" do
  let(:token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:signature) { Calendars::Exports::IcalGenerator::UID_SIGNATURE }
  let!(:user) { create(:user, calendar_token: token) }
  let(:communityB) { create(:community) }

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
        let!(:resource) { create(:resource, name: "Dining Room") }
        let(:meal1_time) { Time.current.midnight + 18.hours }
        let!(:meal1) do
          create(:meal, :with_menu, title: "Meal1", head_cook: user,
                                    served_at: meal1_time, resources: [resource])
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
            location: "#{user.community_abbrv} Dining Room",
            "DTSTART;TZID=Etc/UTC" => I18n.l(meal1_time, format: :iso),
            "DTEND;TZID=Etc/UTC" => I18n.l(meal1_time + 1.hour, format: :iso)
          )
          expect(page).not_to have_content("Meal2")
          expect(page).not_to have_content("Other Cmty Meal")
        end

        scenario "community meals" do
          visit("/calendars/exports/community-meals/#{token}.ics")
          expect_calendar_name("#{user.community.name} Meals")
          expect_events({
            summary: "Meal1"
          }, {
            summary: "Meal2"
          })
          expect(page).not_to have_content("Other Cmty Meal")
        end

        scenario "all meals" do
          visit("/calendars/exports/all-meals/#{token}.ics")
          expect_calendar_name("All Meals")
          expect_events({
            summary: "Meal1"
          }, {
            summary: "Meal2"
          }, {
            summary: "Other Cmty Meal"
          })
        end
      end

      describe "reservations" do
        let(:resource) { create(:resource, name: "Fun Room") }
        let(:reservation1_time) { Time.current + 1.hour }
        let!(:reservation1) do
          create(:reservation, starts_at: reservation1_time, ends_at: reservation1_time + 90.minutes,
                               resource: resource, reserver: user, name: "Games")
        end
        let!(:reservation2) { create(:reservation, starts_at: Time.current + 2.hours, name: "Dance") }
        let!(:other_cmty_reservation) do
          create(:reservation, name: "Nope", resource: create(:resource, community: communityB))
        end

        scenario "your reservations" do
          visit("/calendars/exports/your-reservations/#{token}.ics")
          expect_calendar_name("Your Reservations")
          expect_events(
            summary: "Games (#{user.name})",
            location: "Fun Room",
            description: %r{http://.+/reservations/},
            "DTSTART;TZID=Etc/UTC" => I18n.l(reservation1_time, format: :iso),
            "DTEND;TZID=Etc/UTC" => I18n.l(reservation1_time + 90.minutes, format: :iso)
          )
          expect(page).not_to have_content("Dance")
        end

        scenario "community reservations" do
          visit("/calendars/exports/community-reservations/#{token}.ics")
          expect_calendar_name("#{user.community.name} Reservations")
          expect_events({
            summary: "Games (#{user.name})"
          }, {
            summary: "Dance (#{reservation2.reserver.name})"
          })
        end
      end

      describe "shifts" do
        let(:head_cook_role) { create(:meal_role, :head_cook, description: "Cook something tasty") }
        let(:asst_cook_role) do
          create(:meal_role, title: "Assistant Cook", time_type: "date_time",
                             shift_start: -90, shift_end: 0, description: "Assist the wise cook")
        end
        let(:formula) { create(:meal_formula, roles: [head_cook_role, asst_cook_role]) }

        let(:meal1_time) { Time.current.midnight + 3.days + 18.hours }
        let(:meal2_time) { Time.current.midnight + 7.days + 18.hours }
        let(:meal3_time) { Time.current.midnight + 9.days + 18.hours }
        let(:meal4_time) { Time.current.midnight + 10.days + 18.hours }
        let(:meal5_time) { Time.current.midnight + 11.days + 18.hours }
        let!(:meal1) do
          create(:meal, :with_menu, formula: formula, title: "Figs",
                                    served_at: meal1_time, asst_cooks: [user])
        end
        let!(:meal2) do
          create(:meal, :with_menu, formula: formula, title: "Buns",
                                    served_at: meal2_time, asst_cooks: [user], cleaners: [create(:user)])
        end
        let!(:meal3) do
          create(:meal, :with_menu, formula: formula, title: "Rice",
                                    served_at: meal3_time, asst_cooks: [user])
        end
        let!(:meal4) do
          create(:meal, :with_menu, formula: formula, title: "Corn",
                                    served_at: meal4_time, head_cook: user)
        end
        let!(:meal5) do
          create(:meal, :with_menu, formula: formula, title: "Decoy", served_at: meal5_time)
        end

        let(:period_start) { Time.zone.today }
        let(:period_end) { Time.zone.today + 60.days }
        let(:shift2_1_start) { Time.current.midnight + 2.days }
        let(:period) do
          create(:work_period, starts_on: period_start, ends_on: period_end, phase: "published")
        end
        let!(:job1) do
          create(:work_job, title: "Assistant Cook", period: period, time_type: "date_time",
                            description: "Help cook the things", hours: 2, meal_role_id: asst_cook_role.id,
                            shift_count: 2, shift_starts: [meal1_time - 2.hours, meal2_time - 2.hours])
        end
        let!(:job2) do
          create(:work_job, title: "Single-day", period: period, time_type: "date_only",
                            description: "A very silly job.",
                            shift_count: 2, shift_starts: [shift2_1_start, shift2_1_start + 2.days])
        end
        let!(:job3) do
          create(:work_job, title: "Multi-day", period: period, time_type: "full_period",
                            description: "Do something periodically",
                            shift_count: 1)
        end
        let!(:unpublished_job) do
          create(:work_job, title: "Unpublished", period: create(:work_period, phase: "open"),
                            time_type: "full_period", description: "Do something periodically",
                            shift_count: 1)
        end

        before do
          # Associate meals 1 & 2 (but NOT 3) with appropriate shifts.
          job1.shifts[0].update!(meal_id: meal1.id)
          job1.shifts[1].update!(meal_id: meal2.id)

          # Assign meal shift and other job shifts to user.
          job1.shifts[0].assignments.create!(user: user)
          job1.shifts[1].assignments.create!(user: user)
          job2.shifts[0].assignments.create!(user: user)
          job2.shifts[1].assignments.create!(user: create(:user)) # Decoy
          job3.shifts[0].assignments.create!(user: user)
          unpublished_job.shifts[0].assignments.create!(user: user)
        end

        scenario "includes all meal_assignments and work_assignments" do
          meal3.assignments[1]
          meal4.assignments[0]

          visit("/calendars/exports/your-jobs/#{token}.ics")
          expect_calendar_name("Your Jobs")
          expect_events({
            uid: "#{signature}_Shift_#{job3.shifts[0].id}",
            summary: "Multi-day (Start)",
            location: nil,
            description: %r{Do something periodically\s+\n http://.+/work/signups/},
            "DTSTART;VALUE=DATE" => I18n.l(period_start.to_date, format: :iso),
            "DTEND;VALUE=DATE" => I18n.l(period_start.to_date + 1, format: :iso)
          }, {
            uid: "#{signature}_Shift_#{job3.shifts[0].id}",
            summary: "Multi-day (End)",
            location: nil,
            description: %r{Do something periodically\s+\n http://.+/work/signups/},
            "DTSTART;VALUE=DATE" => I18n.l(period_end.to_date, format: :iso),
            "DTEND;VALUE=DATE" => I18n.l(period_end.to_date + 1, format: :iso)
          }, {
            summary: "Single-day",
            location: nil,
            description: %r{A very silly job\.\s+\n http://.+/work/signups/},
            "DTSTART;VALUE=DATE" => I18n.l(shift2_1_start.to_date, format: :iso),
            "DTEND;VALUE=DATE" => I18n.l(shift2_1_start.to_date + 1, format: :iso)
          }, {
            uid: "#{signature}_Shift_#{job1.shifts[0].id}",
            summary: "Assistant Cook: Figs",
            location: meal1.resources[0].name,
            description: %r{Help cook the things\s+\n http://.+/work/signups/},
            "DTSTART;TZID=Etc/UTC" => I18n.l(meal1_time - 2.hours, format: :iso),
            "DTEND;TZID=Etc/UTC" => I18n.l(meal1_time, format: :iso)
          }, {
            uid: "#{signature}_Shift_#{job1.shifts[1].id}",
            summary: "Assistant Cook: Buns",
            location: meal2.resources[0].name,
            description: %r{Help cook the things\s+\n http://.+/work/signups/},
            "DTSTART;TZID=Etc/UTC" => I18n.l(meal2_time - 2.hours, format: :iso),
            "DTEND;TZID=Etc/UTC" => I18n.l(meal2_time, format: :iso)
          }, {
            # These entries are generated from meal assignments, not work assignments, so
            # the description and timing match the meal role, not the work job.
            # We know to use assignments[1] because the head cook is always [0].
            uid: "#{signature}_Assignment_#{meal3.assignments[1].id}",
            summary: "Assistant Cook: Rice",
            location: meal3.resources[0].name,
            description: %r{Assist the wise cook\s+\n http://.+/meals/},
            "DTSTART;TZID=Etc/UTC" => I18n.l(meal3_time - 90.minutes, format: :iso),
            "DTEND;TZID=Etc/UTC" => I18n.l(meal3_time, format: :iso)
          }, {
            uid: "#{signature}_Assignment_#{meal4.assignments[0].id}",
            summary: "Head Cook: Corn",
            location: meal4.resources[0].name,
            description: %r{Cook something tasty\s+\n http://.+/meals/},
            "DTSTART;VALUE=DATE" => I18n.l(meal4_time.to_date, format: :iso),
            "DTEND;VALUE=DATE" => I18n.l(meal4_time.to_date + 1, format: :iso)
          })
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
      expect_event(event, blocks[i])
    end
  end

  def expect_event(event, block)
    event.each do |key, value|
      if value.nil?
        expect(block).not_to match(/^#{key.to_s.dasherize.upcase}:/)
      else
        key = key.is_a?(Symbol) ? key.to_s.dasherize.upcase : key
        value = value.is_a?(Regexp) ? value : Regexp.quote(value)
        expect(block).to match(/^#{key}:#{value}/)
      end
    end
  end

  def token_from_url
    find("a", text: "All Meals")[:href].match(%r{/([A-Za-z0-9_\-]{20})\.ics})[1]
  end
end
