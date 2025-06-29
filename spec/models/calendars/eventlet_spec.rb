# frozen_string_literal: true

require "rails_helper"

describe Calendars::Eventlet do
  let(:allow_overlap) { false }
  let(:calendar) { create(:calendar, allow_overlap: allow_overlap) }
  let(:calendar2) { create(:calendar) }

  it "has a valid factory" do
    create(:eventlet)
  end

  describe "normalization" do
    let(:eventlet) { build(:eventlet, submitted) }

    describe "all day eventlets" do
      context "with all_day false" do
        let(:submitted) { {all_day: false, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00"} }

        it do
          eventlet.validate
          expect(eventlet.all_day).to be(false)
          expect(eventlet.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
          expect(eventlet.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
        end
      end

      context "with all_day true" do
        before do
          allow(eventlet).to receive(:rule_set).and_return(double(timed_events_only?: timed_only, errors: []))
        end

        context "with calendar permitting all day events" do
          let(:timed_only) { false }
          let(:submitted) { {all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00"} }

          it do
            eventlet.validate
            expect(eventlet.all_day).to be(true)
            expect(eventlet.starts_at.to_fs(:default)).to eq("2016-04-07T00:00:00")
            expect(eventlet.ends_at.to_fs(:default)).to eq("2016-04-07T23:59:59")
          end
        end

        context "with calendar not permitting all day events" do
          let(:timed_only) { true }
          let(:submitted) { {all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00"} }

          it do
            eventlet.validate
            expect(eventlet.all_day).to be(false)
            expect(eventlet.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
            expect(eventlet.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
          end
        end
      end
    end
  end

  describe "location" do
    let(:calendar) { create(:calendar, name: "Fun Room") }
    subject(:location) { eventlet.location }

    context "with persisted event and no explicit location" do
      let(:eventlet) { create(:eventlet, calendar: calendar) }

      it "returns calendar name as location" do
        expect(eventlet.location).to eq("Fun Room")
      end
    end

    context "with persisted event but explicit location" do
      let(:eventlet) { create(:eventlet, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(eventlet.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and explicit location" do
      let(:eventlet) { build(:eventlet, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(eventlet.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and no explicit location" do
      let(:eventlet) { build(:eventlet, calendar: calendar, location: nil) }

      it "returns nil" do
        expect(eventlet.location).to be_nil
      end
    end
  end
end
