# frozen_string_literal: true

require "rails_helper"

describe Calendars::Exports::IcalGenerator do
  let(:export) do
    double(calendar_name: "Foo Calendar", events: events, class_name: "Thing", sample_time: Time.current)
  end
  subject(:ical) { described_class.new(export).generate }

  context "with description array inluding nils" do
    let(:events) { [build(:calendar_export_event, description: ["Short", nil, "Fluff"])] }

    it "breaks lines properly and adds url" do
      is_expected.to match(%r{^DESCRIPTION:Short\s+\n Fluff\s+\n https://you.gather.coop/stuff/123\s+$})
    end
  end
end
