# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
require "rails_helper"

describe Calendars::System::YourJobsCalendar do
  include_context "system calendars"

  let(:actor) { create(:user) }
  let(:calendar) { create(:your_jobs_calendar) }
  let(:full_range) { Date.new(2021, 1, 1)..Date.new(2021, 12, 31) }
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
  let(:meal6_time) { Time.current.midnight + 300.days + 18.hours }
  let!(:meal1) do
    create(:meal, :with_menu, formula: formula, title: "Figs",
                              served_at: meal1_time, asst_cooks: [actor])
  end
  let!(:meal2) do
    create(:meal, :with_menu, formula: formula, title: "Buns",
                              served_at: meal2_time, asst_cooks: [actor], cleaners: [create(:user)])
  end
  let!(:meal3) do
    create(:meal, :with_menu, formula: formula, title: "Rice",
                              served_at: meal3_time, asst_cooks: [actor])
  end
  let!(:meal4) do
    create(:meal, :with_menu, formula: formula, title: "Corn",
                              served_at: meal4_time, head_cook: actor)
  end
  let!(:meal5) do
    create(:meal, :with_menu, formula: formula, title: "Decoy", served_at: meal5_time)
  end
  let!(:meal6) do
    create(:meal, :with_menu, formula: formula, title: "Decoy 2", served_at: meal6_time, head_cook: actor)
  end

  let(:period_start) { Time.zone.today }
  let(:period_end) { Time.zone.today + 120.days } # Stretches past end of date range, but that's ok
  let(:shift2_1_start) { Time.current.midnight + 2.days }
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
                      shift_count: 3,
                      shift_starts: [shift2_1_start, shift2_1_start + 2.days, shift2_1_start + 100.days])
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

  around do |example|
    Timecop.freeze("2021-09-26 9:00") do
      example.run
    end
  end

  before do
    # Associate meals 1 & 2 (but NOT 3) with appropriate shifts.
    job1.shifts[0].update!(meal_id: meal1.id)
    job1.shifts[1].update!(meal_id: meal2.id)

    # Assign meal shift and other job shifts to user.
    job1.shifts[0].assignments.create!(user: actor)
    job1.shifts[1].assignments.create!(user: actor)
    job2.shifts[0].assignments.create!(user: actor)
    job2.shifts[1].assignments.create!(user: create(:user)) # Decoy
    job2.shifts[2].assignments.create!(user: actor) # Also a decoy, because it falls outside date range
    job3.shifts[0].assignments.create!(user: actor)
    draft_job.shifts[0].assignments.create!(user: actor) # Decoy

    meal3.assignments[1]
    meal4.assignments[0]
  end

  it "includes all meal_assignments and work_assignments" do
    attribs = [{
      name: "Multi-day (Start)",
      location: nil,
      note: "Do something periodically",
      uid: "Work_Assignment_#{job3.shifts[0].assignments[0].id}_Start",
      linkable: job3.shifts[0],
      all_day: true,
      starts_at: period_start.midnight,
      ends_at: period_start.midnight + 1.day - 1.second
    }, {
      name: "Single-day",
      location: nil,
      note: "A very silly job\.",
      uid: "Work_Assignment_#{job2.shifts[0].assignments[0].id}",
      linkable: job2.shifts[0],
      all_day: true,
      starts_at: shift2_1_start.midnight,
      ends_at: shift2_1_start.midnight + 1.day - 1.second
    }, {
      name: "Assistant Cook: Figs",
      location: meal1.calendars[0].name,
      note: "Help cook the things",
      uid: "Work_Assignment_#{job1.shifts[0].assignments[0].id}",
      linkable: job1.shifts[0],
      all_day: false,
      starts_at: meal1_time - 2.hours,
      ends_at: meal1_time
    }, {
      name: "Assistant Cook: Buns",
      location: meal2.calendars[0].name,
      note: "Help cook the things",
      uid: "Work_Assignment_#{job1.shifts[1].assignments[0].id}",
      linkable: job1.shifts[1],
      all_day: false,
      starts_at: meal2_time - 2.hours,
      ends_at: meal2_time
    }, {
      # These entries are generated from meal assignments, not work assignments, so
      # the description and timing match the meal role, not the work job.
      # We know to use assignments[1] because the head cook is always [0].
      name: "Assistant Cook: Rice",
      location: meal3.calendars[0].name,
      note: "Assist the wise cook",
      uid: "Meals_Assignment_#{meal3.assignments[1].id}",
      linkable: meal3,
      all_day: false,
      starts_at: meal3_time - 90.minutes,
      ends_at: meal3_time
    }, {
      name: "Head Cook: Corn",
      location: meal4.calendars[0].name,
      note: "Cook something tasty",
      uid: "Meals_Assignment_#{meal4.assignments[0].id}",
      linkable: meal4,
      all_day: true,
      starts_at: meal4_time.midnight,
      ends_at: meal4_time.midnight + 1.day - 1.second
    }, {
      name: "Multi-day (End)",
      location: nil,
      note: "Do something periodically",
      uid: "Work_Assignment_#{job3.shifts[0].assignments[0].id}_End",
      linkable: job3.shifts[0],
      all_day: true,
      starts_at: period_end.midnight,
      ends_at: period_end.midnight + 1.day - 1.second
    }]
    events = calendar.events_between(full_range, actor: actor)
    expect_events(events, *attribs)
  end

  it "returns empty if no actor is given" do
    events = calendar.events_between(full_range, actor: nil)
    expect_events(events, *[])
  end
end
