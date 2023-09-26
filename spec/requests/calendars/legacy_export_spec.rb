# frozen_string_literal: true

require "rails_helper"

describe "legacy calendar exports ICS endpoints" do
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { "mYfEv68-_HG4_lrfGGre" }
  let(:signature) { Calendars::IcalGenerator::UID_SIGNATURE }
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
    let!(:meal5) do
      ActsAsTenant.with_tenant(create(:cluster)) do
        community = create(:community)
        formula = create(:meal_formula, community: community)
        create(:meal, :with_menu, formula: formula, community: community, title: "Meal 5")
      end
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

    # Decoy event from other cluster
    let!(:event4) do
      ActsAsTenant.with_tenant(create(:cluster)) do
        community = create(:community)
        calendar = create(:calendar, community: community)
        create(:event, name: "Event 4", calendar: calendar)
      end
    end
  end

  describe "gen 1 routes (all personalized)" do
    describe "meals" do
      include_context "meals"

      scenario "is properly scoped and personalized" do
        get("/calendars/meals/#{user_token}.ics")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("Meal 1")
        expect(response.body).to include("2 diners from your household")
        expect(response.body).not_to include("Meal 2")
        expect(response.body).not_to include("Meal 3")
        expect(response.body).not_to include("Meal 4")
        expect(response.body).not_to include("Meal 5")

        # Link hostname should get piped in properly and include subdomian
        expect(response.body.gsub("\r\n ", "")).to include("http://default.gatherdev.org:31337/")
      end
    end

    describe "community-meals" do
      include_context "meals"

      scenario "is properly scoped and personalized" do
        get("/calendars/community-meals/#{user_token}.ics")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("Meal 1")
        expect(response.body).to include("2 diners from your household")
        expect(response.body).to include("Meal 2")
        expect(response.body).not_to include("Meal 3")
        expect(response.body).not_to include("Meal 4")
        expect(response.body).not_to include("Meal 5")
      end
    end

    describe "all-meals" do
      include_context "meals"

      scenario "is properly scoped and personalized" do
        get("/calendars/all-meals/#{user_token}.ics")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("Meal 1")
        expect(response.body).to include("2 diners from your household")
        expect(response.body).to include("Meal 2")
        expect(response.body).to include("Meal 3")
        expect(response.body).not_to include("Meal 4")
        expect(response.body).not_to include("Meal 5")
      end
    end

    describe "shifts" do
      include_context "jobs"

      scenario "is properly scoped" do
        get("/calendars/shifts/#{user_token}.ics")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("Job 1")
        expect(response.body).not_to include("Job 2")
      end
    end

    describe "reservations" do
      include_context "events"

      scenario "is properly scoped" do
        get("/calendars/reservations/#{user_token}.ics")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("Event 1")
        expect(response.body).to include("Event 2")
        expect(response.body).not_to include("Event 3")
        expect(response.body).not_to include("Yummy") # Shouldn't include things from system calendars
        expect(response.body).not_to include("Event 4") # Shouldn't include things from other clusters
      end
    end

    describe "your-reservations" do
      include_context "events"

      scenario "is properly scoped" do
        get("/calendars/your-reservations/#{user_token}.ics")
        expect(response).to have_http_status(200)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("Event 1")
        expect(response.body).not_to include("Event 2")
        expect(response.body).not_to include("Event 3")
        expect(response.body).not_to include("Yummy") # Shouldn't include things from system calendars
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
            get("/calendars/exports/meals/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Meal 1")
            expect(response.body).to include("2 diners from your household")
            expect(response.body).not_to include("Meal 2")
            expect(response.body).not_to include("Meal 3")
            expect(response.body).not_to include("Meal 4")
            expect(response.body).not_to include("Meal 5")
          end
        end

        describe "your-meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            get("/calendars/exports/your-meals/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Meal 1")
            expect(response.body).to include("2 diners from your household")
            expect(response.body).not_to include("Meal 2")
            expect(response.body).not_to include("Meal 3")
            expect(response.body).not_to include("Meal 4")
            expect(response.body).not_to include("Meal 5")
          end
        end

        describe "community-meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            get("/calendars/exports/community-meals/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Meal 1")
            expect(response.body).to include("2 diners from your household")
            expect(response.body).to include("Meal 2")
            expect(response.body).not_to include("Meal 3")
            expect(response.body).not_to include("Meal 4")
            expect(response.body).not_to include("Meal 5")
          end
        end

        describe "all-meals" do
          include_context "meals"

          scenario "is properly scoped and personalized" do
            get("/calendars/exports/all-meals/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Meal 1")
            expect(response.body).to include("2 diners from your household")
            expect(response.body).to include("Meal 2")
            expect(response.body).to include("Meal 3")
            expect(response.body).not_to include("Meal 4")
            expect(response.body).not_to include("Meal 5")
          end
        end

        describe "your-jobs" do
          include_context "jobs"

          scenario "is properly scoped" do
            get("/calendars/exports/your-jobs/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Job 1")
            expect(response.body).not_to include("Job 2")
          end
        end

        describe "community-events" do
          include_context "events"

          scenario "is properly scoped" do
            get("/calendars/exports/community-events/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Event 1")
            expect(response.body).to include("Event 2")
            expect(response.body).not_to include("Event 3")
            expect(response.body).not_to include("Yummy") # Shouldn't include things from system calendars
            expect(response.body).not_to include("Event 4") # Shouldn't include things from other clusters
          end
        end

        describe "your-events" do
          include_context "events"

          scenario "is properly scoped" do
            get("/calendars/exports/your-events/#{user_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Event 1")
            expect(response.body).not_to include("Event 2")
            expect(response.body).not_to include("Event 3")
            expect(response.body).not_to include("Yummy") # Shouldn't include things from system calendars
          end
        end
      end

      context "non-personalized" do
        describe "community-meals" do
          include_context "meals"

          scenario "is properly scoped and not personalized" do
            get("/calendars/exports/community-meals/+#{cmty_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Meal 1")
            expect(response.body).to include("Meal 2")
            expect(response.body).not_to include("Meal 3")
            expect(response.body).not_to include("Meal 4")
            expect(response.body).not_to include("Meal 5")
            expect(response.body).not_to include("diners from your household")
          end
        end

        describe "all-meals" do
          include_context "meals"

          scenario "is properly scoped and not personalized" do
            get("/calendars/exports/all-meals/+#{cmty_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Meal 1")
            expect(response.body).to include("Meal 2")
            expect(response.body).to include("Meal 3")
            expect(response.body).not_to include("Meal 4")
            expect(response.body).not_to include("Meal 5")
            expect(response.body).not_to include("diners from your household")
          end
        end

        describe "community-events" do
          include_context "events"

          scenario "is properly scoped" do
            get("/calendars/exports/community-events/+#{cmty_token}.ics")
            expect(response).to have_http_status(200)
            expect(response.body).to include("BEGIN:VCALENDAR")
            expect(response.body).to include("Event 1")
            expect(response.body).to include("Event 2")
            expect(response.body).not_to include("Event 3")
            expect(response.body).not_to include("Yummy") # Shouldn't include things from system calendars
          end
        end
      end

      scenario "bad calendar type" do
        expect { get("/calendars/exports/pants/#{user_token}.ics") }
          .to raise_error(ActionController::RoutingError) # Error reaches here b/c not a JS test.
      end

      scenario "bad user token" do
        get("/calendars/exports/all-meals/totalgarbageofatoken.ics")
        expect(response).to have_http_status(401)
      end

      scenario "bad community token" do
        expect do
          get("/calendars/exports/all-meals/+totalgarbageofatoken.ics")
        end.to raise_error(Pundit::NotAuthorizedError) # Error reaches here b/c not a JS test.
      end
    end
  end
end
