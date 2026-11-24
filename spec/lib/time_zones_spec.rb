# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/time_zones.rb and the tz data the app ships with.
describe "time zones" do
  it "offers British Columbia in the time zone list" do
    zone = ActiveSupport::TimeZone["British Columbia"]
    expect(zone.tzinfo.name).to eq("America/Vancouver")
    expect(ActiveSupport::TimeZone.all).to include(zone)
  end

  it "keeps British Columbia on UTC-7 all year" do
    Time.use_zone("British Columbia") do
      expect(Time.zone.local(2026, 12, 1, 18).utc_offset).to eq(-7.hours)
      expect(Time.zone.local(2027, 7, 1, 18).utc_offset).to eq(-7.hours)
    end
  end
end
