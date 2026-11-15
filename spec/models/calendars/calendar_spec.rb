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

describe Calendars::Calendar do
  describe ".least_used_colors" do
    subject(:color) { described_class.least_used_colors(Defaults.community) }
    let!(:decoy) { create(:calendar, community: create(:community), color: "#75c5c9") }

    before do
      stub_const("#{described_class.name}::COLORS", %w[#75c5c9 #c67033 #910843])
    end

    context "with no existing calendars in community" do
      it { is_expected.to eq(%w[#75c5c9 #c67033 #910843]) }
    end

    context "with one existing calendar" do
      let!(:calendar1) { create(:calendar, community: Defaults.community, color: "#75c5c9") }
      it { is_expected.to eq(%w[#c67033 #910843]) }
    end

    context "with all colors used once" do
      let!(:calendar1) { create(:calendar, community: Defaults.community, color: "#75c5c9") }
      let!(:calendar2) { create(:calendar, community: Defaults.community, color: "#c67033") }
      let!(:calendar3) { create(:calendar, community: Defaults.community, color: "#910843") }
      it { is_expected.to eq(%w[#75c5c9 #c67033 #910843]) }
    end

    context "with more calendars than colors" do
      let!(:calendar1) { create(:calendar, community: Defaults.community, color: "#75c5c9") }
      let!(:calendar2) { create(:calendar, community: Defaults.community, color: "#c67033") }
      let!(:calendar3) { create(:calendar, community: Defaults.community, color: "#75c5c9") }
      let!(:calendar4) { create(:calendar, community: Defaults.community, color: "#910843") }
      it { is_expected.to eq(%w[#c67033 #910843]) }
    end

    context "with even more calendars than colors" do
      let!(:calendar1) { create(:calendar, community: Defaults.community, color: "#75c5c9") }
      let!(:calendar2) { create(:calendar, community: Defaults.community, color: "#c67033") }
      let!(:calendar3) { create(:calendar, community: Defaults.community, color: "#75c5c9") }
      let!(:calendar4) { create(:calendar, community: Defaults.community, color: "#910843") }
      let!(:calendar5) { create(:calendar, community: Defaults.community, color: "#c67033") }
      it { is_expected.to eq(%w[#910843]) }
    end
  end

  describe ".non_system" do
    let!(:cal1) { create(:calendar) }
    let!(:cal2) { create(:calendar) }
    let!(:cal3) { create(:community_meals_calendar) }
    let!(:cal4) { create(:other_communities_meals_calendar) }
    let!(:group) { create(:calendar_group) }

    it "returns only normal calendars" do
      expect(described_class.non_system.to_a).to contain_exactly(cal1, cal2)
    end
  end


  describe "#all_guidelines" do
    let(:calendar) { create(:calendar, :with_shared_guidelines) }
    let(:gl1) { calendar.guidelines }
    let(:gl2) { calendar.shared_guidelines[0].body }
    let(:gl3) { calendar.shared_guidelines[1].body }

    it "combines shared and non-shared guidelines" do
      expect(calendar.all_guidelines).to eq("#{gl1}\n\n---\n\n#{gl2}\n\n---\n\n#{gl3}")
    end
  end

  describe "validation" do
    describe "color" do
      subject(:calendar) { build(:calendar, color: color) }

      context "with valid color and uppercase letters" do
        let(:color) { "#bbFF22" }
        it { is_expected.to be_valid } # Must be normalized b/c regexp is case sensitive.
      end

      context "with missing #" do
        let(:color) { "bbff22" }
        it { is_expected.to have_errors(color: /Must be in hex format \(e.g. #112233\)/) }
      end

      context "with non-hex letter" do
        let(:color) { "#bbfg22" }
        it { is_expected.to have_errors(color: /Must be in hex format \(e.g. #112233\)/) }
      end

      context "with wrong length" do
        let(:color) { "#bbff222" }
        it { is_expected.to have_errors(color: /Must be in hex format \(e.g. #112233\)/) }
      end
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    let!(:calendar) { create(:calendar) }

    context "with events" do
      let!(:event) { create(:event, calendar: calendar) }

      it "destroys events" do
        calendar.destroy
        expect(Calendars::Event.count).to be_zero
      end
    end

    context "with protocols" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar]) }

      it "does not destroy protocols" do
        calendar.destroy
        expect { protocol.reload }.not_to raise_error
      end
    end

    context "with shared guidelines" do
      let!(:calendar) { create(:calendar, :with_shared_guidelines) }

      it "does not destroy guidelines" do
        shared_guideline = calendar.shared_guidelines[0]
        calendar.destroy
        expect { shared_guideline.reload }.not_to raise_error
      end
    end
  end

  describe "repeating events" do
    let(:calendar) { create(:calendar, allow_overlap: true) }

    def series_on(cal, ending: nil)
      rule = IceCube::Rule.weekly
      rule = rule.until(ending) if ending
      start = (ending ? ending - 3.weeks : 1.day.from_now).change(hour: 18)
      create(:event, calendar: cal, recurrence_rule: rule.to_hash, starts_at: start, ends_at: start + 1.hour)
    end

    def protocol_with(calendars: [calendar], community: calendar.community, **rules)
      create(:calendar_protocol, calendars: calendars, community: community, **rules)
    end

    describe "#allows_recurring_events?" do
      it "is true when overlaps are allowed and no protocol blocks them" do
        expect(calendar.allows_recurring_events?).to be(true)
      end

      it "is false when overlaps aren't allowed" do
        expect(create(:calendar, allow_overlap: false).allows_recurring_events?).to be(false)
      end

      {fixed_start_time: "14:00", fixed_end_time: "16:00", max_lead_days: 30, max_days_per_year: 10,
       max_minutes_per_year: 600}.each do |rule, value|
        it "is false with a #{rule} rule" do
          protocol_with(**{rule => value})
          expect(calendar.allows_recurring_events?).to be(false)
        end
      end

      it "is false with a blocking rule limited to some kinds" do
        protocol_with(max_lead_days: 30, kinds: ["Party"])
        expect(calendar.allows_recurring_events?).to be(false)
      end

      it "is false with a blocking rule in a protocol that applies to every calendar" do
        protocol_with(calendars: [], max_lead_days: 30)
        expect(calendar.allows_recurring_events?).to be(false)
      end

      it "ignores protocols that apply only to other calendars or other communities" do
        protocol_with(calendars: [create(:calendar)], max_lead_days: 30)
        protocol_with(calendars: [], community: create(:community), max_lead_days: 30)
        expect(calendar.allows_recurring_events?).to be(true)
      end

      it "is true with rules that every occurrence keeps the same way" do
        protocol_with(max_length_minutes: 120, pre_notice: "Be nice", requires_kind: true)
        expect(calendar.allows_recurring_events?).to be(true)
      end
    end

    describe "#upcoming_recurring_events?" do
      it "is true with a series that doesn't end" do
        series_on(calendar)
        expect(calendar.upcoming_recurring_events?).to be(true)
      end

      it "is true when the series is on this calendar as one of several" do
        series_on(create(:calendar, allow_overlap: true)).eventlets.create!(calendar: calendar)
        expect(calendar.upcoming_recurring_events?).to be(true)
      end

      it "is false once the series has ended" do
        series_on(calendar, ending: 1.week.ago)
        expect(calendar.upcoming_recurring_events?).to be(false)
      end

      it "is false with only non-repeating events" do
        create(:event, calendar: calendar)
        expect(calendar.upcoming_recurring_events?).to be(false)
      end
    end

    describe "turning off overlaps" do
      it "is refused while a series is still to come" do
        series_on(calendar)

        expect(calendar.update(allow_overlap: false)).to be(false)
        expect(calendar.errors[:allow_overlap])
          .to include("must stay on while this calendar has repeating events")
      end

      it "is allowed once every series has ended" do
        series_on(calendar, ending: 1.week.ago)
        expect(calendar.update(allow_overlap: false)).to be(true)
      end

      it "is allowed with no series" do
        expect(calendar.update(allow_overlap: false)).to be(true)
      end
    end
  end
end
