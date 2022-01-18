# frozen_string_literal: true

require "rails_helper"

describe "calendar exports ICS endpoints" do
  let(:community) { create(:community, abbrv: "TS") }
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { community.calendar_token }
  let!(:user) { create(:user, community: community, calendar_token: user_token) }
  let!(:calendar1) { create(:calendar, name: "Fun Room", community: community) }
  let!(:original_event_finder_constructor) { Calendars::EventFinder.method(:new) }

  around do |example|
    Timecop.freeze("2021-01-01 12:00") { example.run }
  end

  before do
    use_user_subdomain(user)
  end

  context "personalized export" do
    context "with specific calendars" do
      let!(:calendar2) { create(:calendar, community: community) }

      it "sends personalized event data" do
        expect(Calendars::EventFinder).to receive(:new) do |args|
          expect(args[:range]).to eq(Time.zone.parse("2020-01-01 12:00")..Time.zone.parse("2022-01-01 12:00"))
          expect(args[:user]).to eq(user)
          expect(args[:calendars]).to contain_exactly(calendar1, calendar2)
          expect(args[:own_only]).to eq(false)
          original_event_finder_constructor.call(args)
        end
        get("/calendars/export.ics?calendars=#{calendar1.id}+#{calendar2.id}&token=#{user_token}")
        expect(response.body).to match("X-WR-CALNAME:2 TS Calendars")
        expect(response.headers["Content-Disposition"]).to match(/attachment; filename="calendars.ics"/)
      end
    end

    context "with no matching calendars" do
      it "still returns ics" do
        expect(Calendars::EventFinder).to receive(:new) do |args|
          expect(args[:calendars]).to be_empty
          original_event_finder_constructor.call(args)
        end
        get("/calendars/export.ics?calendars=82937439287289&token=#{user_token}")
        expect(response.body).to match("X-WR-CALNAME:0 TS Calendars")
      end
    end

    context "with single calendar" do
      it "uses calendar name" do
        get("/calendars/export.ics?calendars=#{calendar1.id}&token=#{user_token}")
        expect(response.body).to match("X-WR-CALNAME:TS Fun Room")
      end
    end

    context "with all calendars" do
      let!(:calendar2) { create(:calendar, community: community) }
      let!(:calendar3) { create(:calendar, community: create(:community)) }

      it "sends appropriate calendars to event finder" do
        expect(Calendars::EventFinder).to receive(:new) do |args|
          expect(args[:calendars]).to contain_exactly(calendar1, calendar2)
          original_event_finder_constructor.call(args)
        end
        get("/calendars/export.ics?calendars=all&token=#{user_token}")
        expect(response.body).to match("X-WR-CALNAME:All TS Calendars")
      end
    end

    context "with own events only" do
      it "requests own events only" do
        expect(Calendars::EventFinder).to receive(:new) do |args|
          expect(args[:own_only]).to be(true)
          original_event_finder_constructor.call(args)
        end
        get("/calendars/export.ics?calendars=all&token=#{user_token}&own_only=1")
      end
    end

    context "with bad user token" do
      it "returns 401" do
        get("/calendars/export.ics?calendars=1&token=xyz")
        expect(response).to be_unauthorized
      end
    end
  end

  context "with non-personalized export" do
    context "with good community token" do
      it "sends non-personalized event data" do
        expect(Calendars::EventFinder).to receive(:new) do |args|
          expect(args[:user]).to be_nil
          original_event_finder_constructor.call(args)
        end
        get("/calendars/community-export.ics?calendars=#{calendar1.id}&token=#{cmty_token}")
      end
    end

    context "with bad community token" do
      it "returns 403" do
        expect do
          get("/calendars/community-export.ics?calendars=#{calendar1.id}&token=xyz")
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
