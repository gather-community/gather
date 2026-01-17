# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletPolicy do
  let(:creator) { create(:user) }
  let(:calendar) { create(:calendar) }

  describe "permissions" do
    include_context "policy permissions"
    let(:created_at) { nil }
    let(:starts_at) { Time.current + 1.week }
    let(:ends_at) { starts_at + 1.hour }
    let(:group) { nil }
    let(:event) do
      create(:event, group: group, creator: creator,
        calendar: calendar, created_at: created_at, starts_at: starts_at, ends_at: ends_at)
    end
    let(:eventlet) do
      event.eventlets[0]
    end
    let(:record) { eventlet }

    shared_examples_for "permits admins or calendar coord or creator or group member but not regular users" do
      it_behaves_like "permits admins or special role but not regular users", :calendar_coordinator

      context "without group" do
        it "permits creator" do
          expect(subject).to permit(creator, event)
        end
      end

      context "with group" do
        let(:joiner) { create(:user) }
        let(:group) { create(:group, joiners: [joiner]) }

        it "permits creator and group member" do
          expect(subject).to permit(creator, event)
          expect(subject).to permit(joiner, event)
        end
      end
    end

    context "with class instead of object" do
      let(:record) { Calendars::Eventlet }

      permissions :index? do
        it_behaves_like "permits active users only"
      end
    end

    context "regular (non-meal) eventlet" do
      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      context "inactive calendar" do
        let(:calendar) { create(:calendar, :inactive) }

        permissions :index?, :new?, :create? do
          it_behaves_like "forbids all"
        end
      end
    end

    # These specs assumes that the user is from a different community since it wouldn't make
    # sense for a rule set to forbid access from the calendar's own community.
    # With forbidden access level, the only outside users that can do the things are cluster admins.
    context "eventlet with calendar with access_level rule for outside communities" do
      before do
        allow(eventlet).to receive(:rule_set).and_return(double(access_level: access_level))
      end

      context "with forbidden access_level" do
        let(:access_level) { "forbidden" }

        permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
          it_behaves_like "permits cluster admins only"
        end
      end

      context "with read_only access_level" do
        let(:access_level) { "read_only" }

        permissions :index?, :show? do
          it_behaves_like "permits active users only"
        end

        permissions :new?, :create?, :edit?, :update?, :destroy? do
          it_behaves_like "permits cluster admins only"
        end
      end

      # For authz purposes, sponsor access level is treated the same as having no rule
      context "with sponsor access_level" do
        let(:access_level) { "sponsor" }

        permissions :index?, :show?, :new?, :create? do
          it_behaves_like "permits active users only"
        end

        permissions :edit?, :update?, :destroy? do
          it_behaves_like "permits admins or calendar coord or creator or group member but not regular users"
        end
      end
    end

    context "meal eventlet" do
      let(:meal) { create(:meal, calendars: [calendar]) }
      let(:event) { create(:event, creator: nil, calendar: calendar, meal: meal, starts_at: meal.served_at, ends_at: meal.served_at + 1.hour, kind: "_meal") }
      let(:eventlet) { event.eventlets[0] }

      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      permissions :new?, :create?, :edit?, :update?, :destroy? do
        it "forbids all" do
          expect(subject).not_to permit(creator, eventlet)
          expect(subject).not_to permit(user, eventlet)
          expect(subject).not_to permit(admin, eventlet)
        end
      end
    end

    context "system calendar eventlet" do
      let(:calendar) { create(:your_meals_calendar) }
      let(:eventlet) { build(:eventlet, calendar: calendar) }

      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      permissions :new?, :create?, :edit?, :update?, :destroy? do
        it "forbids all" do
          expect(subject).not_to permit(creator, eventlet)
          expect(subject).not_to permit(user, eventlet)
          expect(subject).not_to permit(admin, eventlet)
        end
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Calendars::Eventlet }
    let(:calendar) { create(:calendar) }
    let(:calendarB) { create(:calendar, community: communityB) }
    let!(:objs_in_community) { create_list(:eventlet, 2, calendar: calendar) }
    let!(:objs_in_cluster) { create_list(:eventlet, 2, calendar: calendarB) }

    it_behaves_like "permits all users in cluster"
  end
end
