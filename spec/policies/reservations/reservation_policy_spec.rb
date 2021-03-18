# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventPolicy do
  let(:reserver) { create(:user) }
  let(:calendar) { create(:calendar) }

  describe "permissions" do
    include_context "policy permissions"
    let(:created_at) { nil }
    let(:starts_at) { Time.current + 1.week }
    let(:ends_at) { starts_at + 1.hour }
    let(:event) do
      create(:event, reserver: reserver, calendar: calendar, created_at: created_at,
                           starts_at: starts_at, ends_at: ends_at)
    end
    let(:record) { event }

    shared_examples_for "permits admins and reserver" do
      it_behaves_like "permits admins but not regular users"
      it "permits reserver" do
        expect(subject).to permit(reserver, event)
      end
    end

    shared_examples_for "permits admins but not reserver" do
      it_behaves_like "permits admins but not regular users"
      it "forbids reserver" do
        expect(subject).not_to permit(reserver, event)
      end
    end

    permissions :choose_reserver? do
      it_behaves_like "permits admins but not reserver"
    end

    context "non-meal event" do
      permissions :index?, :show?, :new?, :create? do
        it_behaves_like "permits active users only"
      end

      permissions :edit?, :update? do
        it_behaves_like "permits admins and reserver"

        context "just-created event with end time in past" do
          let(:starts_at) { 3.hours.ago }
          let(:created_at) { 50.minutes.ago }
          it_behaves_like "permits admins and reserver"
        end

        context "not-just-created event with end time in past" do
          let(:created_at) { 90.minutes.ago }
          let(:starts_at) { 3.hours.ago }

          it_behaves_like "permits admins and reserver"
        end
      end

      permissions :destroy? do
        context "future event" do
          let(:starts_at) { 1.day.from_now }
          it_behaves_like "permits admins and reserver"
        end

        context "just-created event" do
          let(:starts_at) { 1.day.ago }
          let(:created_at) { 50.minutes.ago }
          it_behaves_like "permits admins and reserver"
        end

        context "not-just-created event" do
          let(:starts_at) { 1.day.ago }
          let(:created_at) { 1.week.ago }
          it_behaves_like "permits admins but not reserver"
        end
      end

      permissions :privileged_change? do
        it_behaves_like "permits admins but not reserver"
      end
    end

    context "meal event" do
      let(:event) { create(:event, reserver: reserver, calendar: calendar, kind: "_meal") }

      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      permissions :new?, :create?, :destroy? do
        it "forbids all" do
          expect(subject).not_to permit(reserver, event)
          expect(subject).not_to permit(user, event)
          expect(subject).not_to permit(admin, event)
        end
      end

      permissions :edit?, :update? do
        it "permits access to admins, meals coordinators, and meal creator, and forbids others" do
          expect(subject).to permit(reserver, event)
          expect(subject).to permit(admin, event)
          expect(subject).to permit(meals_coordinator, event)
          expect(subject).not_to permit(user, event)
        end
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Calendars::Event }
    let(:calendar) { create(:calendar) }
    let(:calendarB) { create(:calendar, community: communityB) }
    let!(:objs_in_community) { create_list(:event, 2, calendar: calendar) }
    let!(:objs_in_cluster) { create_list(:event, 2, calendar: calendarB) }

    it_behaves_like "permits all users in cluster"
  end

  describe "permitted_attributes" do
    include_context "policy permissions"
    let(:event) { create(:event, calendar: calendar) }
    let(:admin_attribs) { basic_attribs + %i[reserver_id] }
    subject { Calendars::EventPolicy.new(reserver, event).permitted_attributes }

    shared_examples_for "basic attribs" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(*basic_attribs)
      end
    end

    shared_examples_for "each user type" do
      context "regular user" do
        it_behaves_like "basic attribs"
      end

      context "admin" do
        let(:reserver) { admin }

        it "should allow admin-only attribs" do
          expect(subject).to contain_exactly(*admin_attribs)
        end
      end

      context "outside admin" do
        let(:reserver) { admin_cmtyB }
        it_behaves_like "basic attribs"
      end
    end

    context "regular event" do
      let(:basic_attribs) { %i[name kind sponsor_id starts_at ends_at guidelines_ok note] }
      it_behaves_like "each user type"
    end

    context "meal event" do
      let(:basic_attribs) { %i[starts_at ends_at note] }
      let(:event) { create(:event, reserver: reserver, calendar: calendar, kind: "_meal") }
      it_behaves_like "each user type"
    end
  end
end
