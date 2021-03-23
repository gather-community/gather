# frozen_string_literal: true

require "rails_helper"

describe Calendars::Group do
  it "has a valid factory" do
    expect(create(:calendar_group, :with_calendars).reload.calendars.size).to eq(2)
  end
end
