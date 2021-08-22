# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::CalendarGenerator do
  let(:generator) { described_class.new(community: Defaults.community, photos: true) }

  it "generates seed data and samples" do
    generator.generate_seed_data
    expect(Calendars::Calendar.count).to eq(4)
    expect(Calendars::Node.count).to eq(6)
    generator.generate_samples
    expect(Calendars::Calendar.count).to be > 4
  end
end
