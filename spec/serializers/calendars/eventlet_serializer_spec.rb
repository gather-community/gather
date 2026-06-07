# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletSerializer do
  describe "#url" do
    context "with regular eventlet" do
      let(:eventlet) { create(:eventlet) }
      subject(:url) { described_class.new(eventlet).url }

      it { is_expected.to eq("/calendars/events/#{eventlet.event.id}") }
    end

    context "with linkable but no occurrence_start (e.g. system calendar eventlet)" do
      let(:meal) { create(:meal) }
      let(:eventlet) { build(:eventlet, linkable: meal) }
      subject(:url) { described_class.new(eventlet).url }

      it { is_expected.to eq("/meals/#{meal.id}") }
    end

    context "with linkable and occurrence_start (transient recurring occurrence)" do
      let(:event) { create(:event) }
      let(:occ_time) { Time.zone.parse("2025-06-10 10:00") }
      let(:eventlet) do
        build(:eventlet, linkable: event).tap { |e| e.occurrence_start = occ_time }
      end
      subject(:url) { described_class.new(eventlet).url }

      it { is_expected.to eq("/calendars/events/#{event.id}?occurrence=#{occ_time.to_i}") }
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
