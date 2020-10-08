# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::WorkGenerator do
  let!(:users) { create_list(:user, 12) }
  let(:generator) { described_class.new(community: Defaults.community) }

  it "generates samples" do
    generator.generate_samples
    expect(Work::Period.count).to eq(1)
    expect(Work::Job.count).to eq(4)
    expect(Work::Assignment.count).to eq(8)
  end
end
