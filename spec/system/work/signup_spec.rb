# frozen_string_literal: true

require "rails_helper"

describe "signups", js: true do
  include_context "work"

  let(:actor) { create(:user) }
  let(:page_path) { work_shifts_path }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  it_behaves_like "handles no periods"

  context "with period but no shifts" do
    let!(:period) { create(:work_period, phase: "ready") }

    scenario "index" do
      visit(page_path)
      expect(page).to have_content("No jobs found")
    end
  end

  context "with jobs" do
    include_context "with jobs"

    context "in draft phase" do
      before { periods[0].update!(phase: "draft") }

      scenario "index" do
        visit(page_path)
        expect(page).to have_content("This period is in the draft phase so workers can't sign up")
      end
    end

    # NOTE: See below for testing of shift_date_range lens
    describe "filters and search", search: Work::Shift do
      include_context "with assignments"

      scenario do
        visit(page_path)

        select_lens(:shift, "All Jobs")
        expect_jobs(*jobs[0..3])

        # Check for fork/knife icon
        expect(page).to have_content("Cook")
        expect(page).to have_css("i.fa-cutlery")

        fill_in_lens(:search, "fruct")
        expect_jobs(jobs[1])

        clear_lenses
        expect_jobs(*jobs[0..3])

        select_lens(:shift, "Open Jobs")
        expect_jobs(*jobs[1..3])

        select_lens(:shift, "Your Jobs")
        expect_jobs(*jobs[1..2])

        select_lens(:shift, "Your Household")
        expect_jobs(*jobs[0..2])

        select_lens(:shift, "Not Preassigned")
        expect_jobs(*jobs[1..3])

        select_lens(:shift, "Pants")
        expect_jobs(jobs[1], jobs[3])

        select_lens(:shift, "All Jobs")
        select_lens(:period, periods[1].name)
        expect_jobs(jobs[4])
      end
    end

    describe "signup, show, unsignup, autorefresh", clean_with_transaction: false do
      before do
        periods[0].update!(phase: "open")
      end

      # Need to clean with truncation because we are doing stuff with txn isolation which is forbidden
      # inside nested transactions.
      scenario do
        visit(page_path)

        within(".shift-card[data-id='#{jobs[0].shifts[0].id}']") do
          expect(page).not_to have_content(actor.name)
          click_on("Sign Up!")
          expect(page).to have_content(actor.name)
        end

        within(".shift-card[data-id='#{jobs[1].shifts[0].id}']") do
          with_env("STUB_SIGNUP_ERROR" => "Work::SlotsExceededError") do
            click_on("Sign Up!")
            expect(page).to have_content("someone beat you to it")
          end
        end

        within(".shift-card[data-id='#{jobs[1].shifts[1].id}']") do
          with_env("STUB_SIGNUP_ERROR" => "Work::AlreadySignedUpError") do
            click_on("Sign Up!")
            expect(page).to have_content("already signed up for")
          end
        end

        # Unsignup via #show page
        click_on("Cook")
        expect(page).to have_content(jobs[0].description)
        accept_confirm { click_on("Remove Signup") }

        within(".shift-card[data-id='#{jobs[0].shifts[0].id}']") do
          expect(page).not_to have_content(actor.name)
          click_on("Sign Up!")
          expect(page).to have_content(actor.name)

          # Unsignup via 'x' link
          accept_confirm { find(".cancel-link a").click }
          expect(page).not_to have_content(actor.name)
        end

        # Test autorefresh by simulating someone else having signed up.
        within(".shift-card[data-id='#{jobs[2].shifts[0].id}']") do
          expect(page).not_to have_content(users[0].name)
          jobs[2].shifts[0].signup_user(users[0])
          expect(page).to have_content(users[0].name)
        end
      end
    end

    describe "staggering and auto open" do
      let(:open_time) { Time.current.tomorrow.midnight + 12.hours }
      let!(:share) { create(:work_share, period: periods[0], user: actor) }

      before do
        periods[0].update!(
          auto_open_time: open_time,
          phase: "ready",
          pick_type: "staggered",
          quota_type: "by_person",
          workers_per_round: 3,
          round_duration: 5,
          max_rounds_per_worker: 3,
          quota: 32
        )
      end

      scenario do
        visit(page_path)
        time = I18n.l(open_time, format: :wday_no_year)
        expect(page).to have_content("You have signed up for 0/32 hours. " \
                                     "You can start choosing jobs on #{time}")
        Timecop.freeze(open_time + 2.minutes) do
          visit(page_path)
          time = I18n.l(open_time + 5.minutes, format: :time_only)
          expect(page).to have_content("You have signed up for 0/32 hours. " \
                                       "Your round limit is 11 hours and will rise to 22 at #{time}")
        end
        expect(periods[0].reload.phase).to eq("open")
      end
    end
  end

  context "with past, present, and future jobs" do
    let!(:period) do
      create(:work_period, starts_on: Time.zone.today - 83.days, ends_on: Time.zone.today + 7.days,
                           phase: "open")
    end
    let!(:jobs) do
      [
        create(:work_job, period: period, title: "Moldy Oldy", time_type: "date_only",
                          shift_slots: 1,
                          shift_starts: [Time.current - 2.days],
                          shift_ends: [Time.current - 2.days]),
        create(:work_job, period: period, title: "Current Durrant", time_type: "date_only",
                          shift_slots: 1,
                          shift_starts: [Time.current - 1.day],
                          shift_ends: [Time.current + 1.day]),
        create(:work_job, period: period, title: "Future Scoocher", time_type: "date_only",
                          shift_slots: 1,
                          shift_starts: [Time.current + 2.days],
                          shift_ends: [Time.current + 2.days])
      ]
    end

    context "with default initial_selection (all)" do
      scenario do
        visit(page_path)
        expect(page).to have_select_lens(:dates, selected: "Past & Future")
        expect_jobs(*jobs[0..2])

        select_lens(:dates, "Current & Future")
        expect_jobs(*jobs[1..2])

        select_lens(:dates, "Past Only")
        expect_jobs(*jobs[0])
      end
    end

    context "with default initial_selection (all)" do
      scenario "lenses work properly" do
        visit(page_path)
        expect(page).to have_select_lens(:dates, selected: "Past & Future")
        expect_jobs(*jobs[0..2])

        select_lens(:dates, "Current & Future")
        expect_jobs(*jobs[1..2])

        select_lens(:dates, "Past Only")
        expect_jobs(*jobs[0])
      end
    end

    context "with current & future initial_selection" do
      before do
        Defaults.community.update!(settings: {work: {default_date_filter: "curftr"}})
      end

      scenario "lenses work properly" do
        visit(page_path)
        expect(page).to have_select_lens(:dates, selected: "Current & Future")
        expect(page).to have_lens_clear_link
        expect_jobs(*jobs[1..2])

        clear_lenses
        expect(page).to have_select_lens(:dates, selected: "Past & Future")
        expect_jobs(*jobs[0..2])

        visit(page_path)
        expect(page).to have_select_lens(:dates, selected: "Current & Future")
        expect(page).to have_lens_clear_link
      end
    end
  end
end
