# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::PeopleGenerator do
  let(:generator) { described_class.new(community: Defaults.community) }

  it "generates samples" do
    generator.generate_samples
    expect(User.count).to be > 0
    expect(Household.count).to be > 0
    expect(People::Memorial.count).to eq(1)
    expect(People::MemorialMessage.count).to eq(1)
  end
end
