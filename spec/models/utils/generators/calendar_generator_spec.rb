# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::CalendarGenerator do
  let(:generator) { described_class.new(community: Defaults.community, photos: true) }

  it "generates seed data and samples" do
    generator.generate_seed_data
    expect(Calendars::Calendar.count).to eq(7)
    expect(Calendars::Node.count).to eq(10)
    generator.generate_samples
    expect(Calendars::Calendar.count).to be > 7

    kitchen = Calendars::Calendar.find_by!(name: "Kitchen")
    expect(kitchen.abbrv).to eq("CH")
    expect(kitchen.guidelines).to start_with("# Kitchen Guidelines")
    expect(kitchen.shared_guidelines.map(&:name)).to eq(["Common House Guidelines"])
    office = Calendars::Calendar.find_by!(name: "Office")
    expect(office.abbrv).to be_nil
    expect(office.guidelines).to be_nil
    expect(office.shared_guidelines.map(&:name)).to eq(["Common House Guidelines"])
  end
end
