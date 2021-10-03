# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventSerializer do
  describe "#url" do
    context "with regular event" do
      let(:event) { create(:event) }
      subject(:url) { described_class.new(event).url }

      it { is_expected.to eq("/calendars/events/#{event.id}") }
    end

    context "with meal linkable" do
      let(:meal) { create(:meal) }
      let(:event) { build(:event, linkable: meal) }
      subject(:url) { described_class.new(event).url }

      it { is_expected.to eq("/meals/#{meal.id}") }
    end
  end
end
