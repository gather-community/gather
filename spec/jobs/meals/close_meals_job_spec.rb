# frozen_string_literal: true

require "rails_helper"

describe Meals::CloseMealsJob do
  include_context "jobs"

  let!(:meal1) { create(:meal, :open, served_at: Time.current - 3.hours) }
  let!(:meal2) { create(:meal, :open, served_at: Time.current - 1.hour) }
  let!(:meal3) { create(:meal, :open, served_at: Time.current + 1.hour) }
  let!(:meal4) { create(:meal, :open, auto_close_time: Time.current + 1.hour) }

  # We can't set auto_close_time to a value in the past so we use Timecop to go to the time we want to
  # set and then set auto_close_time to the current time + 1.second. (auto_close_time must be in future,
  # hence the + 1.second)
  let!(:meal5) do
    Timecop.freeze(Time.current - 2.minutes) do
      create(:meal, :open, auto_close_time: Time.current + 1.second, served_at: Time.current + 7.days)
    end
  end
  let!(:meal6) do
    Timecop.freeze(Time.current - 1.day) do
      create(:meal, :open, auto_close_time: Time.current + 1.second, served_at: Time.current + 7.days)
    end
  end
  let!(:meal7) do
    Timecop.freeze(Time.current - 1.day) do
      create(:meal, :closed, auto_close_time: Time.current + 1.second, served_at: Time.current + 7.days)
    end
  end
  let!(:meal8) do
    Timecop.freeze(Time.current - 1.day) do
      create(:meal, :finalized, auto_close_time: Time.current + 1.second, served_at: Time.current + 7.days)
    end
  end

  it "closes meals with auto_close_time set and meals more than 3 hours in the past" do
    perform_job
    expect(meal1.reload).to be_closed
    expect(meal2.reload).to be_open
    expect(meal3.reload).to be_open
    expect(meal4.reload).to be_open
    expect(meal5.reload).to be_closed
    expect(meal6.reload).to be_closed
    expect(meal7.reload).to be_closed
    expect(meal8.reload).to be_finalized
  end
end
