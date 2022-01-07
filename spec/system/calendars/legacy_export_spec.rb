# frozen_string_literal: true

require "rails_helper"

describe "calendar export" do
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { "mYfEv68-_HG4_lrfGGre" }
  let(:signature) { Calendars::Exports::LegacyIcalGenerator::UID_SIGNATURE }
  let!(:user) { create(:user, calendar_token: user_token) }
  let(:community) { Defaults.community }
  let(:communityB) { create(:community) }
  let(:gen1_cal_types) { %w[meals community-meals all-meals shifts reservations your-reservations] }
  let(:gen2_pub_cal_types) { %w[community-meals all-meals community-events] }
  let(:gen2_psn_cal_types) do
    %w[meals your-meals community-meals all-meals your-jobs community-events your-events]
  end

  before do
    community.update!(calendar_token: cmty_token)
  end

  shared_context "meals" do
    let!(:meal1) { create(:meal, :with_menu, title: "Meal 1") }
    let!(:meal2) { create(:meal, :with_menu, title: "Meal 2") }
    let!(:meal3) do
      create(:meal, :with_menu, title: "Meal 3", community: communityB, communities: [community, communityB])
    end
    let!(:meal4) do # main community not invited
      create(:meal, :with_menu, title: "Meal 4", community: communityB, communities: [communityB])
    end
    let!(:signup1) do
      create(:meal_signup, meal: meal1, household: user.household, diner_counts: [2])
    end
    let!(:system_calendars) do
      create(:your_meals_calendar)
      create(:community_meals_calendar)
      create(:other_communities_meals_calendar)
    end
  end

  shared_context "jobs" do
    let!(:period) { create(:work_period, starts_on: Time.zone.today, phase: "published") }
    let!(:job1) { create(:work_job, period: period, title: "Job 1", time_type: "full_period") }
    let!(:job2) { create(:work_job, period: period, title: "Job 2", time_type: "full_period") }
    let!(:system_calendars) do
      create(:your_jobs_calendar)
    end

    before do
      job1.shifts[0].assignments.create!(user: user)
    end
  end

  shared_context "events" do
    let!(:calendar1) { create(:calendar, community: community) }
    let!(:calendar2) { create(:calendar, community: community) }
    let!(:calendar3) { create(:calendar, community: communityB) }
    let!(:event1) { create(:event, calendar: calendar1, name: "Event 1", creator: user) }
    let!(:event2) { create(:event, calendar: calendar2, name: "Event 2") }
    let!(:event3) { create(:event, calendar: calendar3, name: "Event 3", creator: user) }

    # Decoy meal for testing that system cal events not included
    let!(:meal) { create(:meal, :with_menu, title: "Yummy Meal") }
    let!(:signup) { create(:meal_signup, meal: meal, household: user.household, diner_counts: [2]) }
  end

  describe "gen 1 routes (all personalized)" do
    describe "meals" do
      include_context "meals"

      scenario "is properly scoped and personalized" do
        visit("/calendars/meals/#{user_token}.ics")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_content("Meal 1")
        expect(page).to have_content("2 diners from your household")
        expect(page).not_to have_content("Meal 2")
        expect(page).not_to have_content("Meal 3")
        expect(page).not_to have_content("Meal 4")

        # Ensure there was no redirection to user's subdomain.
        # We don't want to redirect when fetching ICS in case some clients don't support that.
        expect(current_url).not_to match(user.community.slug)
      end
    end

    describe "community-meals" do
      include_context "meals"

      scenario "is properly scoped and personalized" do
        visit("/calendars/community-meals/#{user_token}.ics")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_content("Meal 1")
        expect(page).to have_content("2 diners from your household")
        expect(page).to have_content("Meal 2")
        expect(page).not_to have_content("Meal 3")
        expect(page).not_to have_content("Meal 4")
      end
    end

    describe "all-meals" do
      include_context "meals"

      scenario "is properly scoped and personalized" do
        visit("/calendars/all-meals/#{user_token}.ics")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_content("Meal 1")
        expect(page).to have_content("2 diners from your household")
        expect(page).to have_content("Meal 2")
        expect(page).to have_content("Meal 3")
        expect(page).not_to have_content("Meal 4")
      end
    end

    describe "shifts" do
      include_context "jobs"

      scenario "is properly scoped" do
        visit("/calendars/shifts/#{user_token}.ics")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_content("Job 1")
        expect(page).not_to have_content("Job 2")
      end
    end

    describe "reservations" do
      include_context "events"

      scenario "is properly scoped" do
        visit("/calendars/reservations/#{user_token}.ics")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_content("Event 1")
        expect(page).to have_content("Event 2")
        expect(page).not_to have_content("Event 3")
        expect(page).not_to have_content("Yummy") # Shouldn't include things from system calendars
      end
    end

    describe "your-reservations" do
      include_context "events"

      scenario "is properly scoped" do
        visit("/calendars/your-reservations/#{user_token}.ics")
        expect(page).to have_http_status(200)
        expect(page).to have_content("BEGIN:VCALENDAR")
        expect(page).to have_content("Event 1")
        expect(page).not_to have_content("Event 2")
        expect(page).not_to have_content("Event 3")
        expect(page).not_to have_content("Yummy") # Shouldn't include things from system calendars
      end
    end
  end

  describe "gen 2 routes" do
    context "with user subdomain" do
      let!(:meal) { create(:meal) }

      before do
        use_user_subdomain(user)
      end

      context "personalized" do
        describe "meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            visit("/calendars/exports/meals/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Meal 1")
            expect(page).to have_content("2 diners from your household")
            expect(page).not_to have_content("Meal 2")
            expect(page).not_to have_content("Meal 3")
            expect(page).not_to have_content("Meal 4")
          end
        end

        describe "your-meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            visit("/calendars/exports/your-meals/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Meal 1")
            expect(page).to have_content("2 diners from your household")
            expect(page).not_to have_content("Meal 2")
            expect(page).not_to have_content("Meal 3")
            expect(page).not_to have_content("Meal 4")
          end
        end

        describe "community-meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            visit("/calendars/exports/community-meals/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Meal 1")
            expect(page).to have_content("2 diners from your household")
            expect(page).to have_content("Meal 2")
            expect(page).not_to have_content("Meal 3")
            expect(page).not_to have_content("Meal 4")
          end
        end

        describe "all-meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            visit("/calendars/exports/all-meals/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Meal 1")
            expect(page).to have_content("2 diners from your household")
            expect(page).to have_content("Meal 2")
            expect(page).to have_content("Meal 3")
            expect(page).not_to have_content("Meal 4")
          end
        end

        describe "your-jobs" do
          include_context "jobs"

          scenario "is properly scoped" do
            visit("/calendars/exports/your-jobs/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Job 1")
            expect(page).not_to have_content("Job 2")
          end
        end

        describe "community-events" do
          include_context "events"

          scenario "is properly scoped" do
            visit("/calendars/exports/community-events/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Event 1")
            expect(page).to have_content("Event 2")
            expect(page).not_to have_content("Event 3")
            expect(page).not_to have_content("Yummy") # Shouldn't include things from system calendars
          end
        end

        describe "your-events" do
          include_context "events"

          scenario "is properly scoped" do
            visit("/calendars/exports/your-events/#{user_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Event 1")
            expect(page).not_to have_content("Event 2")
            expect(page).not_to have_content("Event 3")
            expect(page).not_to have_content("Yummy") # Shouldn't include things from system calendars
          end
        end
      end

      context "non-personalized" do
        describe "community-meals" do
          include_context "meals"

          scenario "is properly scoped and not personalized" do
            visit("/calendars/exports/community-meals/+#{cmty_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Meal 1")
            expect(page).to have_content("Meal 2")
            expect(page).not_to have_content("Meal 3")
            expect(page).not_to have_content("Meal 4")
            expect(page).not_to have_content("diners from your household")
          end
        end

        describe "all-meals" do
          include_context "meals"

          scenario "is properly scoped and not personalized" do
            visit("/calendars/exports/all-meals/+#{cmty_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Meal 1")
            expect(page).to have_content("Meal 2")
            expect(page).to have_content("Meal 3")
            expect(page).not_to have_content("Meal 4")
            expect(page).not_to have_content("diners from your household")
          end
        end

        describe "community-events" do
          include_context "events"

          scenario "is properly scoped" do
            visit("/calendars/exports/community-events/+#{cmty_token}.ics")
            expect(page).to have_http_status(200)
            expect(page).to have_content("BEGIN:VCALENDAR")
            expect(page).to have_content("Event 1")
            expect(page).to have_content("Event 2")
            expect(page).not_to have_content("Event 3")
            expect(page).not_to have_content("Yummy") # Shouldn't include things from system calendars
          end
        end
      end

      scenario "bad calendar type" do
        expect { visit("/calendars/exports/pants/#{user_token}.ics") }
          .to raise_error(ActionController::RoutingError) # Error reaches here b/c not a JS test.
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
    end
  end
end
