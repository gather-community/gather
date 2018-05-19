# frozen_string_literal: true

require "rails_helper"

feature "signups", js: true do
  include_context "work"

  let(:actor) { create(:user) }

  let(:index_path) { work_shifts_path }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  it_behaves_like "handles no periods"

  context "with period but no shifts" do
    let!(:period) { create(:work_period) }

    scenario "index" do
      visit(index_path)
      expect(page).to have_content("No jobs found")
    end
  end

  context "with jobs" do
    include_context "with jobs"

    describe "filters and search", search: Work::Shift do
      include_context "with assignments"

      scenario do
        visit(index_path)

        select_lens(:shift, "All Jobs")
        expect_jobs(*jobs[0..3])

        find(".lens-bar.upper [name=search]").set("fruct")
        find(".lens-bar.upper [name=search]").native.send_keys(:return)
        expect_jobs(jobs[1])

        clear_lenses
        expect_jobs(*jobs[0..3])

        select_lens(:shift, "Open Jobs")
        expect_jobs(*jobs[1..3])

        select_lens(:shift, "My Jobs")
        expect_jobs(*jobs[1..2])

        select_lens(:shift, "My Household")
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

    describe "signup, show, unsignup, autorefresh", database_cleaner: :truncate do
      before do
        periods[0].update!(phase: "open")
      end

      # Need to clean with truncation because we are doing stuff with txn isolation which is forbidden
      # inside nested transactions.
      scenario do
        visit(index_path)

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

        click_on("Knembler")
        expect(page).to have_content(jobs[0].description)
        accept_confirm { click_on("Remove Signup") }

        within(".shift-card[data-id='#{jobs[0].shifts[0].id}']") do
          expect(page).not_to have_content(actor.name)
          click_on("Sign Up!")
          expect(page).to have_content(actor.name)
        end

        # Test autorefresh by simulating someone else having signed up.
        within(".shift-card[data-id='#{jobs[2].shifts[0].id}']") do
          expect(page).not_to have_content(users[0].name)
          jobs[2].shifts[0].signup_user(users[0])
          expect(page).to have_content(users[0].name)
        end
      end
    end
  end
end
