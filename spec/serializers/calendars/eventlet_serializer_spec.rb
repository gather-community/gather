# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletSerializer do
  describe "#url" do
    context "with regular eventlet" do
      let(:eventlet) { create(:eventlet) }
      subject(:url) { described_class.new(eventlet).url }

      it { is_expected.to eq("/calendars/eventlets/#{eventlet.id}") }
    end

    context "with linkable but no occurrence_start (e.g. system calendar eventlet)" do
      let(:meal) { create(:meal) }
      let(:eventlet) { build(:eventlet, linkable: meal) }
      subject(:url) { described_class.new(eventlet).url }

      it { is_expected.to eq("/meals/#{meal.id}") }
    end

    context "with linkable and occurrence_start (transient recurring occurrence)" do
      # linkable is the persisted base eventlet; the occurrence URL is eventlet-centric.
      let(:base_eventlet) { create(:eventlet) }
      let(:occ_time) { Time.zone.parse("2025-06-10 10:00") }
      let(:eventlet) do
        build(:eventlet, linkable: base_eventlet).tap { |e| e.occurrence_start = occ_time }
      end
      subject(:url) { described_class.new(eventlet).url }

      it { is_expected.to eq("/calendars/eventlets/#{base_eventlet.id}?occurrence=#{occ_time.to_i}") }
    end
  end

  describe "serialized ids" do
    # The grid's drag handler keys updates off event_id (the events endpoint), so the feed must carry
    # both the eventlet id and the event id, since the two are not aligned in production.
    let(:eventlet) { create(:eventlet) }
    subject(:attrs) { described_class.new(eventlet, scope: create(:user)).serializable_hash }

    it "includes both the eventlet id and the event id" do
      expect(attrs[:id]).to eq(eventlet.id)
      expect(attrs[:event_id]).to eq(eventlet.event_id)
    end
  end

  describe "drag scope attributes" do
    # These drive the two drag prompts: "this calendar vs. all calendars" (eventlet_count) and
    # "this occurrence vs. the whole series" (recurring + occurrence_start).
    subject(:attrs) { described_class.new(eventlet, scope: create(:user)).serializable_hash }

    context "with a plain non-recurring eventlet" do
      let(:eventlet) { create(:eventlet) }

      it "reports no occurrence, not recurring, and a single eventlet" do
        expect(attrs[:occurrence_start]).to be_nil
        expect(attrs[:recurring]).to be(false)
        expect(attrs[:eventlet_count]).to eq(1)
      end
    end

    context "with an event spanning multiple calendars" do
      let(:eventlet) { create(:eventlet) }

      before do
        Calendars::Eventlet.create!(event_id: eventlet.event_id, calendar: create(:calendar),
          start_offset: -1.hour.to_i)
      end

      it "reports the full eventlet count" do
        expect(attrs[:eventlet_count]).to eq(2)
      end
    end

    context "with a transient recurring occurrence" do
      let(:base_eventlet) do
        create(:eventlet).tap do |e|
          e.event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash)
        end
      end
      let(:occ_time) { Time.zone.parse("2025-06-10 10:00") }
      let(:eventlet) do
        build(:eventlet, linkable: base_eventlet).tap { |e| e.occurrence_start = occ_time }
      end

      it "reports the occurrence and resolves recurring/count through the series event" do
        expect(attrs[:occurrence_start]).to eq(occ_time.to_i)
        expect(attrs[:recurring]).to be(true)
        expect(attrs[:eventlet_count]).to eq(1)
      end
    end
  end

  describe "#class_name" do
    let(:user) { create(:user) }
    subject(:class_name) { described_class.new(eventlet, scope: user).class_name }

    context "with regular eventlet" do
      context "with creator as user" do
        let(:eventlet) { create(:eventlet, creator: user) }

        it { is_expected.to eq("own-event") }
      end

      context "with creator as user but group present" do
        let(:eventlet) { create(:eventlet, creator: user, group: create(:group)) }

        it { is_expected.to eq("own-group-event") }
      end
    end

    context "with meal eventlet" do
      let(:eventlet) { build(:eventlet) }

      before { allow(eventlet).to receive(:meal?).and_return(true) }

      it { is_expected.to eq("has-meal") }
    end
  end
end
