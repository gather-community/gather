# frozen_string_literal: true

require "rails_helper"

describe Calendars::InitialSelection do
  let!(:calendar1) { create(:calendar, id: 1, selected_by_default: true) }
  let!(:calendar2) { create(:calendar, id: 2, selected_by_default: false) }
  let!(:calendar3) { create(:calendar, id: 3, selected_by_default: true) }
  let!(:calendar4) { create(:calendar, id: 4, selected_by_default: false) }
  let!(:decoy) { create(:calendar, id: 5, selected_by_default: false) }
  let(:base_scope) { Calendars::Calendar.where(id: [1, 2, 3, 4]) }
  subject(:selection) { described_class.new(stored: setting, calendar_scope: base_scope).selection }

  context "with null stored setting" do
    let(:setting) { nil }
    it { is_expected.to eq("1": true, "2": false, "3": true, "4": false) }
  end

  context "with non-null stored setting" do
    let(:setting) { {"1": false, "2": true} }
    it { is_expected.to eq("1": false, "2": true, "3": true, "4": false) }
  end
end
