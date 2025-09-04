# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
require "rails_helper"

describe Calendars::System::JoinDatesCalendar do
  include_context "system calendars"

  let(:actor) { create(:user) }
  let(:calendar) { create(:join_dates_calendar) }
  let!(:user1) do
    create(:user, first_name: "Jo", last_name: "Fiz", joined_on: "Jan 28 2013")
  end
  let(:full_range) { Date.new(2021, 1, 1)..Date.new(2021, 12, 31) }

  around do |example|
    Timecop.freeze("2021-09-26 9:00") do
      example.run
    end
  end

  it "returns correct event attribs" do
    attribs = [{
      name: "➕ Jo Fiz (8)",
      starts_at: Time.zone.parse("2021-01-28 00:00"),
      ends_at: Time.zone.parse("2021-01-28 23:59:59"),
      all_day: true,
      creator_id: nil,
      note: nil,
      linkable: user1,
      uid: "join_dates_#{user1.id}"
    }]
    events = calendar.events_between(full_range, actor: actor)
    expect_events(events, *attribs)
  end
end
