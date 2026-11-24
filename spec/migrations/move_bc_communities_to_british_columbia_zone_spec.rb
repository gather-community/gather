# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261124120000_move_bc_communities_to_british_columbia_zone")

describe MoveBcCommunitiesToBritishColumbiaZone do
  let!(:ravens) { create(:community, slug: "ravenscrossing") }
  let!(:little) { create(:community, slug: "littlemountain") }
  let!(:other) { create(:community) }

  before do
    set_zone(ravens, "Mountain Time (US & Canada)")
    set_zone(little, "Arizona")
    set_zone(other, "Mountain Time (US & Canada)")
  end

  it "moves the listed communities to British Columbia without changing stored times" do
    meal = create(:meal, community: ravens)
    served_at = Time.utc(2027, 7, 2, 1)
    meal.update_columns(served_at: served_at)

    migrate(:up)

    expect(zone(ravens)).to eq("British Columbia")
    expect(zone(little)).to eq("British Columbia")
    expect(zone(other)).to eq("Mountain Time (US & Canada)")
    expect(meal.reload.served_at).to eq(served_at)

    migrate(:down)

    expect(zone(ravens)).to eq("Mountain Time (US & Canada)")
    expect(zone(little)).to eq("Arizona")
    expect(zone(other)).to eq("Mountain Time (US & Canada)")
  end

  it "skips a listed community whose zone has already been changed" do
    set_zone(ravens, "Eastern Time (US & Canada)")

    migrate(:up)

    expect(zone(ravens)).to eq("Eastern Time (US & Canada)")
    expect(zone(little)).to eq("British Columbia")
  end

  def set_zone(community, zone)
    Community.where(id: community.id).update_all(
      ["settings = jsonb_set(COALESCE(settings, '{}'), '{time_zone}', to_jsonb(?::text))", zone]
    )
  end

  def zone(community)
    community.reload.settings.time_zone
  end

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end
end
