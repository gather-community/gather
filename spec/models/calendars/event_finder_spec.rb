# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventFinder do
  let(:user) { create(:user) }
  let(:t0) { Time.current.midnight }
  let(:range) { (t0 + 2.5.hours)..(t0 + 4.5.hours) }
  let(:group) { create(:group) }
  let!(:cal1) { create(:calendar) }
  let!(:cal2) { create(:community_meals_calendar) }
  let!(:cal3) { create(:calendar) }
  let!(:cal4) { create(:other_communities_meals_calendar) }
  let!(:event1_1) do
    create(:event, calendar: cal1, starts_at: t0 + 1.hour, ends_at: t0 + 2.hours, creator: user)
  end
  let!(:event1_2) do
    create(:event, calendar: cal1, starts_at: t0 + 2.hours, ends_at: t0 + 3.hours, creator: user)
  end
  let!(:event1_3) do
    create(:event, calendar: cal1, starts_at: t0 + 3.hours, ends_at: t0 + 4.hours, creator: user,
                   group: group)
  end
  let!(:event1_4) { create(:event, calendar: cal1, starts_at: t0 + 4.hours, ends_at: t0 + 5.hours) }
  let!(:event1_5) { create(:event, calendar: cal1, starts_at: t0 + 5.hours, ends_at: t0 + 6.hours) }
  let!(:event2_1) { build(:event, calendar: cal2, starts_at: t0 + 2.hours, ends_at: t0 + 5.hours) }
  let!(:event3_1) { create(:event, calendar: cal3, starts_at: t0 + 3.hours, ends_at: t0 + 4.hours) }
  let!(:event4_1) { build(:event, calendar: cal4, starts_at: t0 + 3.hours, ends_at: t0 + 4.hours) }
  let(:own_only) { false }
  subject(:events) do
    described_class.new(range: range, calendars: calendars, user: user, own_only: own_only).events
  end

  before do
    allow(cal2).to receive(:events_between).with(range, {actor: user}).and_return(event2_1)
    allow(cal4).to receive(:events_between).with(range, {actor: user}).and_return(event4_1)
  end

  context "with no calendars" do
    let(:calendars) { [] }

    it "returns empty array" do
      is_expected.to be_empty
    end
  end

  context "with calendars" do
    let(:calendars) { [cal1, cal2, cal4] }

    context "with all events" do
      let(:own_only) { false }

      it "returns events in range and from calendars only" do
        is_expected.to contain_exactly(event1_2, event1_3, event1_4, event2_1, event4_1)
      end

      it "respects policy scope for non-system calendars" do
        null_scope = double(resolve: Calendars::Event.none)
        expect(Calendars::EventPolicy::Scope).to receive(:new).and_return(null_scope)
        is_expected.to contain_exactly(event2_1, event4_1)
      end
    end

    context "with user created events only" do
      let(:own_only) { true }

      it "includes user-created, non-group events only" do
        is_expected.to contain_exactly(event1_2)
      end
    end

    context "with no user" do
      it "still returns events" do
        is_expected.to contain_exactly(event1_2, event1_3, event1_4, event2_1, event4_1)
      end
    end
  end
end
