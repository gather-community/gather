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

describe Calendars::System::BirthdaysCalendar do
  include_context "system calendars"

  let(:actor) { create(:user) }
  let(:calendar) { create(:birthdays_calendar) }
  let!(:user1) do
    create(:user, first_name: "Jo", last_name: "Fiz", birthday_str: "Jan 28")
  end
  let!(:user2) do
    create(:user, :child, first_name: "Bo", last_name: "Biz", birthday_str: "1996-02-29")
  end
  let!(:user3) do
    create(:user, first_name: "Ko", last_name: "Xiz", birthday_str: "2008-02-19")
  end
  let!(:user4) do
    create(:user, birthdate: nil)
  end
  let!(:inactive) do
    create(:user, :inactive, first_name: "Zo", last_name: "Ziz", birthday_str: "2008-02-17")
  end
  let!(:other_cmty) do
    create(:user, first_name: "Zo", last_name: "Kiz", birthday_str: "1980-02-20",
      community: create(:community))
  end
  let(:full_range) { Date.new(2021, 1, 1)..Date.new(2021, 12, 31) }

  around do |example|
    Timecop.freeze("2021-09-26 9:00") do
      example.run
    end
  end

  it "returns correct event attribs" do
    attribs = [{
      name: "🎂 Jo Fiz",
      starts_at: Time.zone.parse("2021-01-28 00:00"),
      ends_at: Time.zone.parse("2021-01-28 23:59:59"),
      all_day: true,
      creator_id: nil,
      note: nil,
      linkable: user1,
      uid: "birthdays_#{user1.id}"
    }, {
      name: "🎂 Ko Xiz (13)",
      starts_at: Time.zone.parse("2021-02-19 00:00"),
      ends_at: Time.zone.parse("2021-02-19 23:59:59"),
      all_day: true,
      creator_id: nil,
      note: nil,
      linkable: user3,
      uid: "birthdays_#{user3.id}"
    }, {
      name: "🎂 Bo Biz", # Don't include age if age > 18
      starts_at: Time.zone.parse("2021-02-28 00:00"), # Observe Feb 29 on Feb 28 in non-leap year
      ends_at: Time.zone.parse("2021-02-28 23:59:59"),
      all_day: true,
      creator_id: nil,
      note: nil,
      linkable: user2,
      uid: "birthdays_#{user2.id}"
    }]
    events = calendar.events_between(full_range, actor: actor)
    expect_events(events, *attribs)
  end

  it "returns correct events inside tighter range" do
    events = calendar.events_between(Date.new(2021, 2, 1)..Date.new(2021, 2, 20), actor: actor)
    expect_events(events, name: "🎂 Ko Xiz (13)")
  end

  it "returns correct events inside longer range" do
    events = calendar.events_between(Date.new(2020, 2, 1)..Date.new(2023, 2, 20), actor: actor)
    attribs = [
      {name: "🎂 Ko Xiz (12)", starts_at: Time.zone.parse("19 Feb 2020 00:00:00")},
      {name: "🎂 Bo Biz", starts_at: Time.zone.parse("29 Feb 2020 00:00:00")},
      {name: "🎂 Jo Fiz", starts_at: Time.zone.parse("28 Jan 2021 00:00:00")},
      {name: "🎂 Ko Xiz (13)", starts_at: Time.zone.parse("19 Feb 2021 00:00:00")},
      {name: "🎂 Bo Biz", starts_at: Time.zone.parse("28 Feb 2021 00:00:00")},
      {name: "🎂 Jo Fiz", starts_at: Time.zone.parse("28 Jan 2022 00:00:00")},
      {name: "🎂 Ko Xiz (14)", starts_at: Time.zone.parse("19 Feb 2022 00:00:00")},
      {name: "🎂 Bo Biz", starts_at: Time.zone.parse("28 Feb 2022 00:00:00")},
      {name: "🎂 Jo Fiz", starts_at: Time.zone.parse("28 Jan 2023 00:00:00")},
      {name: "🎂 Ko Xiz (15)", starts_at: Time.zone.parse("19 Feb 2023 00:00:00")}
    ]
    expect_events(events, *attribs)
  end
end
