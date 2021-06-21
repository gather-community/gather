# frozen_string_literal: true

require "rails_helper"

describe "work exports" do
  include_context "calendar exports"

  let(:head_cook_role) { create(:meal_role, :head_cook, description: "Cook something tasty") }
  let(:asst_cook_role) do
    create(:meal_role, title: "Assistant Cook", time_type: "date_time",
                       shift_start: -90, shift_end: 0, description: "Assist the wise cook")
  end
  let(:cleaner_role) { create(:meal_role, title: "Cleaner") }
  let(:formula) { create(:meal_formula, roles: [head_cook_role, asst_cook_role, cleaner_role]) }

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
  let(:period2) do
    create(:work_period, starts_on: period_start, ends_on: period_end, phase: "draft")
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
  let!(:draft_job) do
    create(:work_job, title: "Unpublished", period: period2,
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
    draft_job.shifts[0].assignments.create!(user: user) # Decoy
  end

  context "your jobs" do
    subject(:ical_data) { Calendars::Exports::YourJobsExport.new(user: user).generate }

    it "includes all meal_assignments and work_assignments" do
      meal3.assignments[1]
      meal4.assignments[0]

      expect_calendar_name("Your Jobs")
      expect_events({
        uid: "#{signature}_Work_Assignment_#{job3.shifts[0].assignments[0].id}_Start",
        summary: "Multi-day (Start)",
        location: nil,
        description: %r{Do something periodically\s+\n http://.+/work/signups/},
        "DTSTART;VALUE=DATE" => period_start.to_date.to_s(:no_sep),
        "DTEND;VALUE=DATE" => (period_start.to_date + 1).to_s(:no_sep)
      }, {
        uid: "#{signature}_Work_Assignment_#{job3.shifts[0].assignments[0].id}_End",
        summary: "Multi-day (End)",
        location: nil,
        description: %r{Do something periodically\s+\n http://.+/work/signups/},
        "DTSTART;VALUE=DATE" => period_end.to_date.to_s(:no_sep),
        "DTEND;VALUE=DATE" => (period_end.to_date + 1).to_s(:no_sep)
      }, {
        summary: "Single-day",
        location: nil,
        description: %r{A very silly job\.\s+\n http://.+/work/signups/},
        "DTSTART;VALUE=DATE" => shift2_1_start.to_date.to_s(:no_sep),
        "DTEND;VALUE=DATE" => (shift2_1_start.to_date + 1).to_s(:no_sep)
      }, {
        uid: "#{signature}_Work_Assignment_#{job1.shifts[0].assignments[0].id}",
        summary: "Assistant Cook: Figs",
        location: meal1.calendars[0].name,
        description: %r{Help cook the things\s+\n http://.+/work/signups/},
        "DTSTART;TZID=Etc/UTC" => (meal1_time - 2.hours).to_s(:no_sep),
        "DTEND;TZID=Etc/UTC" => meal1_time.to_s(:no_sep)
      }, {
        uid: "#{signature}_Work_Assignment_#{job1.shifts[1].assignments[0].id}",
        summary: "Assistant Cook: Buns",
        location: meal2.calendars[0].name,
        description: %r{Help cook the things\s+\n http://.+/work/signups/},
        "DTSTART;TZID=Etc/UTC" => (meal2_time - 2.hours).to_s(:no_sep),
        "DTEND;TZID=Etc/UTC" => meal2_time.to_s(:no_sep)
      }, {
        # These entries are generated from meal assignments, not work assignments, so
        # the description and timing match the meal role, not the work job.
        # We know to use assignments[1] because the head cook is always [0].
        uid: "#{signature}_Meals_Assignment_#{meal3.assignments[1].id}",
        summary: "Assistant Cook: Rice",
        location: meal3.calendars[0].name,
        description: %r{Assist the wise cook\s+\n http://.+/meals/},
        "DTSTART;TZID=Etc/UTC" => (meal3_time - 90.minutes).to_s(:no_sep),
        "DTEND;TZID=Etc/UTC" => meal3_time.to_s(:no_sep)
      }, {
        uid: "#{signature}_Meals_Assignment_#{meal4.assignments[0].id}",
        summary: "Head Cook: Corn",
        location: meal4.calendars[0].name,
        description: %r{Cook something tasty\s+\n http://.+/meals/},
        "DTSTART;VALUE=DATE" => meal4_time.to_date.to_s(:no_sep),
        "DTEND;VALUE=DATE" => (meal4_time.to_date + 1).to_s(:no_sep)
      })
    end
  end
end
