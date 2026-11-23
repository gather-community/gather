# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261123120000_move_british_columbia_communities_to_vancouver_time")

describe MoveBritishColumbiaCommunitiesToVancouverTime do
  # Times as Los Angeles clocks read them, saved the way Gather saved them before this change.
  let(:winter) { Time.utc(2026, 12, 2, 2) } # 6pm on 1 Dec, UTC-8.
  let(:winter_in_bc) { Time.utc(2026, 12, 2, 1) } # The same 6pm at UTC-7.
  let(:next_winter) { Time.utc(2028, 1, 10, 20) } # Noon, UTC-8.
  let(:next_winter_in_bc) { Time.utc(2028, 1, 10, 19) }
  let(:summer) { Time.utc(2027, 7, 2, 1) } # 6pm, UTC-7 in both zones.
  let(:before_change) { Time.utc(2026, 1, 15, 2) } # 6pm, UTC-8 in both zones at the time.

  let(:bc_community) { Defaults.community }
  let!(:us_community) { create(:community) }

  before do
    set_zone(bc_community, "CA", "Pacific Time (US & Canada)")
    set_zone(us_community, "US", "Pacific Time (US & Canada)")
  end

  it "moves Canadian Pacific communities to British Columbia and keeps their scheduled clock times" do
    meal = create(:meal, community: bc_community)
    meal.update_columns(served_at: winter, auto_close_time: summer)
    event = create(:event, calendar: create(:calendar, community: bc_community))
    event.update_columns(starts_at: winter, ends_at: next_winter)
    override = create(:event_override, event: event, occurrence_start: winter, starts_at: summer)
    period = create(:work_period, community: bc_community)
    period.update_columns(auto_open_time: before_change)
    shift = create(:work_shift, job: create(:work_job, period: period))
    shift.update_columns(starts_at: winter, ends_at: next_winter)
    reminder = create(:meal_role_reminder, role: create(:meal_role, community: bc_community))
    reminder.update_columns(abs_time: winter)
    delivery = create(:meal_role_reminder_delivery, reminder: reminder, meal: meal)
    delivery.update_columns(deliver_at: winter)
    signup = create(:communities_signup, country_code: "CA", time_zone: "Pacific Time (US & Canada)")

    us_meal = create(:meal, community: us_community)
    us_meal.update_columns(served_at: winter)

    migrate(:up)

    expect(bc_community.reload.settings.time_zone).to eq("British Columbia")
    expect(times(meal.reload, :served_at, :auto_close_time)).to eq([winter_in_bc, summer])
    expect(times(event.reload, :starts_at, :ends_at)).to eq([winter_in_bc, next_winter_in_bc])
    expect(times(override.reload, :occurrence_start, :starts_at)).to eq([winter_in_bc, summer])
    expect(times(period.reload, :auto_open_time)).to eq([before_change])
    expect(times(shift.reload, :starts_at, :ends_at)).to eq([winter_in_bc, next_winter_in_bc])
    expect(times(reminder.reload, :abs_time)).to eq([winter_in_bc])
    expect(times(delivery.reload, :deliver_at)).to eq([winter_in_bc])
    expect(signup.reload.time_zone).to eq("British Columbia")

    # A US community on the same zone is left alone.
    expect(us_community.reload.settings.time_zone).to eq("Pacific Time (US & Canada)")
    expect(times(us_meal.reload, :served_at)).to eq([winter])

    # The clock time people entered is what the new zone shows.
    Time.use_zone("British Columbia") { expect(meal.reload.served_at.strftime("%H:%M")).to eq("18:00") }

    migrate(:down)

    expect(bc_community.reload.settings.time_zone).to eq("Pacific Time (US & Canada)")
    expect(times(meal.reload, :served_at, :auto_close_time)).to eq([winter, summer])
    expect(times(event.reload, :starts_at, :ends_at)).to eq([winter, next_winter])
    expect(times(override.reload, :occurrence_start, :starts_at)).to eq([winter, summer])
    expect(times(delivery.reload, :deliver_at)).to eq([winter])
    expect(signup.reload.time_zone).to eq("Pacific Time (US & Canada)")
  end

  it "leaves Canadian communities in other zones alone" do
    set_zone(bc_community, "CA", "Eastern Time (US & Canada)")
    meal = create(:meal, community: bc_community)
    meal.update_columns(served_at: winter)

    migrate(:up)

    expect(bc_community.reload.settings.time_zone).to eq("Eastern Time (US & Canada)")
    expect(times(meal.reload, :served_at)).to eq([winter])
  end

  def set_zone(community, country_code, zone)
    Community.where(id: community.id).update_all(
      ["country_code = ?, settings = jsonb_set(COALESCE(settings, '{}'), '{time_zone}', to_jsonb(?::text))",
        country_code, zone]
    )
  end

  def times(record, *attribs)
    attribs.map { |a| record[a].utc }
  end

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end
end
