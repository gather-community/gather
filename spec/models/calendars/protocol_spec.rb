# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_protocols
#
#  id                   :integer          not null, primary key
#  cluster_id           :integer          not null
#  community_id         :integer          not null
#  created_at           :datetime         not null
#  fixed_end_time       :time
#  fixed_start_time     :time
#  kinds                :jsonb
#  max_days_per_year    :integer
#  max_lead_days        :integer
#  max_length_minutes   :integer
#  max_minutes_per_year :integer
#  name                 :string           not null
#  other_communities    :string
#  pre_notice           :text
#  requires_kind        :boolean
#  updated_at           :datetime         not null
#
require "rails_helper"

describe Calendars::Protocol do
  describe "normalization" do
    let(:protocol) { build(:calendar_protocol, submitted) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, protocol.send(k)] }.to_h }

    before do
      protocol.validate
    end

    describe "requires_kind" do
      context "with false" do
        let(:submitted) { {requires_kind: false} }
        it { is_expected.to eq(requires_kind: nil) }
      end

      context "with true and blank kind" do
        let(:submitted) { {requires_kind: true, kinds: [""]} }
        it { is_expected.to eq(requires_kind: true, kinds: nil) }
      end

      context "with nils" do
        let(:submitted) { {requires_kind: nil, kinds: nil} }
        it { is_expected.to eq(requires_kind: nil, kinds: nil) }
      end

      context "with true but also with kinds" do
        let(:submitted) { {requires_kind: true, kinds: ["Personal"]} }
        it { is_expected.to eq(requires_kind: nil, kinds: ["Personal"]) }
      end
    end

    describe "kinds" do
      context "with blanks" do
        let(:submitted) { {kinds: ["", "Personal", "", "Official"]} }
        it { is_expected.to eq(kinds: %w[Personal Official]) }
      end
    end
  end

  describe ".matching" do
    let(:calendar1) { create(:calendar, community: create(:community)) }
    let(:calendar2) { create(:calendar, community: create(:community)) }
    let(:calendar3) { create(:calendar, community: create(:community)) }
    let!(:p1) { create(:calendar_protocol, calendars: [calendar1]) }
    let!(:p2) { create(:calendar_protocol, calendars: [calendar1], kinds: %w[Personal Special]) }
    let!(:p3) { create(:calendar_protocol, calendars: [calendar1], kinds: %w[Official]) }
    let!(:p4) { create(:calendar_protocol, calendars: [calendar2]) }
    let!(:p5) { create(:calendar_protocol, community: calendar1.community) }
    let!(:p6) { create(:calendar_protocol, community: calendar1.community, kinds: %w[Personal Official]) }
    let!(:p7) { create(:calendar_protocol, community: calendar1.community, kinds: []) }

    it "should find protocols with matching calendar or no calendar, and matching kind or no kind" do
      expect(Calendars::Protocol.matching(calendar1, "Personal")).to contain_exactly(p1, p2, p5, p6, p7)
    end

    it "should only match protocols with no kind if given kind doesn't match any" do
      expect(Calendars::Protocol.matching(calendar1, "foo")).to contain_exactly(p1, p5, p7)
    end

    it "should only match protocols with no kind if no kind given" do
      expect(Calendars::Protocol.matching(calendar1)).to contain_exactly(p1, p5, p7)
    end

    it "should only match protocols with any kind if no kind == :any" do
      expect(Calendars::Protocol.matching(calendar1, :any)).to contain_exactly(p1, p2, p3, p5, p6, p7)
    end

    it "should match correct protocols for different community" do
      expect(Calendars::Protocol.matching(calendar2)).to contain_exactly(p4)
    end

    it "should return [] on no match" do
      expect(Calendars::Protocol.matching(calendar3)).to be_empty
    end
  end

  describe "time column behavior" do
    let(:calendar1) { create(:calendar) }

    before { Time.zone = "Saskatchewan" }

    context "with time already stored in database" do
      let!(:p1) { create(:calendar_protocol, calendars: [calendar1]) }

      before do
        # Deliberately doing this via SQL so we know the actual value stored in the DB.
        ActiveRecord::Base.connection.execute(
          "UPDATE calendar_protocols SET fixed_start_time = '2000-01-01 13:00'"
        )
      end

      it "does not apply timezone on retrieval" do
        expect(p1.reload.fixed_start_time.hour).to eq(13)
      end
    end

    context "with time provided at creation" do
      let!(:p1) { create(:calendar_protocol, calendars: [calendar1], fixed_start_time: "13:00") }

      it "returns correct time" do
        expect(p1.reload.fixed_start_time.hour).to eq(13)
      end
    end
  end

  # A rule a repeating event can't keep to (Protocol::RECURRENCE_BLOCKING_RULES) can't reach a calendar
  # with a series still to come, by any route.
  describe "rules that block repeating events" do
    let(:calendar) { create(:calendar, name: "Courtyard", allow_overlap: true) }
    let(:other) { create(:calendar, name: "Office", allow_overlap: true) }
    let(:community) { calendar.community }

    before do
      start = 1.day.from_now.change(hour: 18)
      create(:event, calendar: calendar, recurrence_rule: IceCube::Rule.weekly.to_hash,
        starts_at: start, ends_at: start + 1.hour)
    end

    def new_protocol(calendars:, **rules)
      described_class.new(name: "Rules", community: community, calendar_ids: calendars.map(&:id), **rules)
    end

    def expect_refused(protocol)
      expect(protocol.errors[:base].join).to match(/can't apply to Courtyard, which have repeating events/)
    end

    it "refuses a new one on a calendar with a series" do
      protocol = new_protocol(calendars: [calendar], max_lead_days: 30)
      expect(protocol.save).to be(false)
      expect_refused(protocol)
    end

    it "refuses a new one that applies to every calendar" do
      protocol = new_protocol(calendars: [], fixed_start_time: "14:00")
      expect(protocol.save).to be(false)
      expect_refused(protocol)
    end

    it "allows one on a calendar without a series" do
      expect(new_protocol(calendars: [other], max_lead_days: 30).save).to be(true)
    end

    it "allows rules that every occurrence keeps the same way" do
      protocol = new_protocol(calendars: [calendar], max_length_minutes: 120, pre_notice: "Be nice")
      expect(protocol.save).to be(true)
    end

    it "refuses adding a blocking rule to an existing protocol" do
      protocol = new_protocol(calendars: [calendar], max_length_minutes: 120).tap(&:save!)
      expect(protocol.update(max_minutes_per_year: 600)).to be(false)
      expect_refused(protocol)
    end

    it "refuses adding the calendar to a protocol that has one, leaving its calendars as they were" do
      protocol = new_protocol(calendars: [other], max_lead_days: 30).tap(&:save!)

      expect(protocol.update(calendar_ids: [other.id, calendar.id])).to be(false)
      expect_refused(protocol)
      expect(protocol.reload.calendars).to eq([other])
    end

    it "refuses removing a protocol's last calendar, which would make it apply to every calendar" do
      protocol = new_protocol(calendars: [other], max_lead_days: 30).tap(&:save!)

      expect(protocol.update(calendar_ids: [])).to be(false)
      expect_refused(protocol)
      expect(protocol.reload.calendars).to eq([other])
    end

    it "ignores a series that has ended" do
      Calendars::Event.recurring.each do |series|
        series.update!(recurrence_rule: IceCube::Rule.weekly.until(1.week.ago).to_hash,
          starts_at: 3.weeks.ago, ends_at: 3.weeks.ago + 1.hour)
      end
      expect(new_protocol(calendars: [calendar], max_lead_days: 30).save).to be(true)
    end
  end
end
