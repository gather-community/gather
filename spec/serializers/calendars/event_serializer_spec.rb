# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_events
#
#  id          :integer          not null, primary key
#  all_day     :boolean          default(FALSE), not null
#  calendar_id :integer          not null
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  creator_id  :integer
#  ends_at     :datetime         not null
#  group_id    :bigint
#  kind        :string
#  meal_id     :integer
#  name        :string(24)       not null
#  note        :text
#  sponsor_id  :integer
#  starts_at   :datetime         not null
#  updated_at  :datetime         not null
#
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

  describe "#class_name" do
    let(:user) { create(:user) }
    subject(:class_name) { described_class.new(event, scope: user).class_name }

    context "with regular event" do
      context "with creator as user" do
        let(:event) { create(:event, creator: user) }

        it { is_expected.to eq("own-event") }
      end

      context "with creator as user but group present" do
        let(:event) { create(:event, creator: user, group: create(:group)) }

        it { is_expected.to eq("own-group-event") }
      end
    end

    context "with meal" do
      let(:meal) { create(:meal) }
      let(:event) { build(:event, meal: meal) }

      it { is_expected.to eq("has-meal") }
    end
  end
end
