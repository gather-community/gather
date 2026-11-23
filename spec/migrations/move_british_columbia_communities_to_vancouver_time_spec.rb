# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261123120000_move_british_columbia_communities_to_vancouver_time")

describe MoveBritishColumbiaCommunitiesToVancouverTime do
  # Each time is 6pm local as saved under the old zone, paired with 6pm in Vancouver.
  let(:mtn_summer) { Time.utc(2027, 7, 2, 0) } # 6pm MDT (UTC-6).
  let(:mtn_summer_in_bc) { Time.utc(2027, 7, 2, 1) } # 6pm, UTC-7.
  let(:mtn_winter) { Time.utc(2026, 12, 2, 1) } # 6pm MST (UTC-7), already right.
  let(:mtn_last_summer) { Time.utc(2025, 7, 2, 0) } # 6pm MDT, when BC was on PDT (UTC-7).
  let(:mtn_last_summer_in_bc) { Time.utc(2025, 7, 2, 1) }
  let(:az_last_winter) { Time.utc(2025, 12, 2, 1) } # 6pm UTC-7, when BC was on PST (UTC-8).
  let(:az_last_winter_in_bc) { Time.utc(2025, 12, 2, 2) }
  let(:az_winter) { Time.utc(2026, 12, 2, 1) } # 6pm UTC-7, same in BC now.

  let!(:ravens) { create(:community, slug: "ravenscrossing") }
  let!(:little) { create(:community, slug: "littlemountain") }
  let!(:other) { create(:community) }

  before do
    set_zone(ravens, "Mountain Time (US & Canada)")
    set_zone(little, "Arizona")
    set_zone(other, "Mountain Time (US & Canada)")
  end

  it "moves the listed communities to British Columbia and keeps their scheduled clock times" do
    meal = create(:meal, community: ravens)
    meal.update_columns(served_at: mtn_summer, auto_close_time: mtn_winter)
    event = create(:event, calendar: create(:calendar, community: ravens))
    event.update_columns(starts_at: mtn_summer, ends_at: mtn_last_summer)
    override = create(:event_override, event: event, occurrence_start: mtn_summer, starts_at: mtn_winter)
    period = create(:work_period, community: ravens)
    period.update_columns(auto_open_time: mtn_last_summer)
    shift = create(:work_shift, job: create(:work_job, period: period))
    shift.update_columns(starts_at: mtn_summer, ends_at: mtn_winter)
    reminder = create(:meal_role_reminder, role: create(:meal_role, community: ravens))
    reminder.update_columns(abs_time: mtn_summer)
    delivery = create(:meal_role_reminder_delivery, reminder: reminder, meal: meal)
    delivery.update_columns(deliver_at: mtn_summer)

    little_meal = create(:meal, community: little)
    little_meal.update_columns(served_at: az_last_winter, auto_close_time: az_winter)

    other_meal = create(:meal, community: other)
    other_meal.update_columns(served_at: mtn_summer)

    migrate(:up)

    expect(ravens.reload.settings.time_zone).to eq("British Columbia")
    expect(times(meal.reload, :served_at, :auto_close_time)).to eq([mtn_summer_in_bc, mtn_winter])
    expect(times(event.reload, :starts_at, :ends_at)).to eq([mtn_summer_in_bc, mtn_last_summer_in_bc])
    expect(times(override.reload, :occurrence_start, :starts_at)).to eq([mtn_summer_in_bc, mtn_winter])
    expect(times(period.reload, :auto_open_time)).to eq([mtn_last_summer_in_bc])
    expect(times(shift.reload, :starts_at, :ends_at)).to eq([mtn_summer_in_bc, mtn_winter])
    expect(times(reminder.reload, :abs_time)).to eq([mtn_summer_in_bc])
    expect(times(delivery.reload, :deliver_at)).to eq([mtn_summer_in_bc])

    expect(little.reload.settings.time_zone).to eq("British Columbia")
    expect(times(little_meal.reload, :served_at, :auto_close_time)).to eq([az_last_winter_in_bc, az_winter])

    # A community that isn't listed is left alone, even on the same zone.
    expect(other.reload.settings.time_zone).to eq("Mountain Time (US & Canada)")
    expect(times(other_meal.reload, :served_at)).to eq([mtn_summer])

    # The clock time people entered is what the new zone shows.
    Time.use_zone("British Columbia") { expect(meal.reload.served_at.strftime("%H:%M")).to eq("18:00") }

    migrate(:down)

    expect(ravens.reload.settings.time_zone).to eq("Mountain Time (US & Canada)")
    expect(times(meal.reload, :served_at, :auto_close_time)).to eq([mtn_summer, mtn_winter])
    expect(times(event.reload, :starts_at, :ends_at)).to eq([mtn_summer, mtn_last_summer])
    expect(times(override.reload, :occurrence_start, :starts_at)).to eq([mtn_summer, mtn_winter])
    expect(times(delivery.reload, :deliver_at)).to eq([mtn_summer])
    expect(little.reload.settings.time_zone).to eq("Arizona")
    expect(times(little_meal.reload, :served_at, :auto_close_time)).to eq([az_last_winter, az_winter])
  end

  it "skips a listed community whose zone has already been changed" do
    set_zone(ravens, "Eastern Time (US & Canada)")
    meal = create(:meal, community: ravens)
    meal.update_columns(served_at: mtn_summer)

    migrate(:up)

    expect(ravens.reload.settings.time_zone).to eq("Eastern Time (US & Canada)")
    expect(times(meal.reload, :served_at)).to eq([mtn_summer])
  end

  def set_zone(community, zone)
    Community.where(id: community.id).update_all(
      ["settings = jsonb_set(COALESCE(settings, '{}'), '{time_zone}', to_jsonb(?::text))", zone]
    )
  end

  def times(record, *attribs)
    attribs.map { |a| record[a].utc }
  end

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end
end
