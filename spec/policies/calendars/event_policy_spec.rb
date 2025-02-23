# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventPolicy do
  let(:creator) { create(:user) }
  let(:calendar) { create(:calendar) }

  describe "permissions" do
    include_context "policy permissions"
    let(:created_at) { nil }
    let(:starts_at) { Time.current + 1.week }
    let(:ends_at) { starts_at + 1.hour }
    let(:group) { nil }
    let(:event) do
      create(:event, creator: creator, calendar: calendar, created_at: created_at,
                     group: group, starts_at: starts_at, ends_at: ends_at)
    end
    let(:record) { event }

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

    shared_examples_for "permits admins or calendar coord but not creator" do
      it_behaves_like "permits admins or special role but not regular users", :calendar_coordinator

      it "forbids creator" do
        expect(subject).not_to permit(creator, event)
      end
    end

    permissions :choose_creator?, :privileged_change? do
      it_behaves_like "permits admins or calendar coord but not creator"
    end

    context "with class instead of object" do
      let(:record) { Calendars::Event }

      permissions :index? do
        it_behaves_like "permits active users only"
      end

      permissions :show?, :new?, :create?, :edit?, :update?, :privileged_change?,
                  :choose_creator?, :destroy? do
        it_behaves_like "forbids all"
      end
    end

    context "regular (non-meal) event" do
      permissions :index?, :show?, :new?, :create? do
        it_behaves_like "permits active users only"
      end

      permissions :edit?, :update? do
        it_behaves_like "permits admins or calendar coord or creator or group member but not regular users"

        context "just-created event with end time in past" do
          let(:starts_at) { 3.hours.ago }
          let(:created_at) { 50.minutes.ago }
          it_behaves_like "permits admins or calendar coord or creator or group member but not regular users"
        end

        context "not-just-created event with end time in past" do
          let(:created_at) { 90.minutes.ago }
          let(:starts_at) { 3.hours.ago }
          it_behaves_like "permits admins or calendar coord or creator or group member but not regular users"
        end
      end

      context "inactive calendar" do
        let(:calendar) { create(:calendar, :inactive) }

        permissions :index?, :new?, :create? do
          it_behaves_like "forbids all"
        end
      end

      permissions :destroy? do
        context "future event" do
          let(:starts_at) { 1.day.from_now }
          it_behaves_like "permits admins or calendar coord or creator or group member but not regular users"
        end

        context "just-created event" do
          let(:starts_at) { 1.day.ago }
          let(:created_at) { 50.minutes.ago }
          it_behaves_like "permits admins or calendar coord or creator or group member but not regular users"
        end

        context "not-just-created event" do
          let(:starts_at) { 1.day.ago }
          let(:created_at) { 1.week.ago }
          it_behaves_like "permits admins or calendar coord but not creator"
        end
      end
    end

    # These specs assumes that the user is from a different community since it wouldn't make
    # sense for a rule set to forbid access from the calendar's own community.
    # With forbidden access level, the only outside users that can do the things are cluster admins.
    context "event with calendar with access_level rule for outside communities" do
      before do
        allow(event).to receive(:rule_set).and_return(double(access_level: access_level))
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

    context "meal event" do
      let(:meal) { create(:meal, calendars: [calendar]) }
      let(:event) do
        create(:event, creator: nil, calendar: calendar, meal: meal, starts_at: meal.served_at,
                       ends_at: meal.served_at + 1.hour, kind: "_meal")
      end

      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      permissions :new?, :create?, :destroy? do
        it "forbids all" do
          expect(subject).not_to permit(creator, event)
          expect(subject).not_to permit(user, event)
          expect(subject).not_to permit(admin, event)
        end
      end

      permissions :edit?, :update? do
        it "permits access to admins, meals/cal coordinators, and forbids others" do
          expect(subject).to permit(admin, event)
          expect(subject).to permit(meals_coordinator, event)
          expect(subject).to permit(calendar_coordinator, event)
          expect(subject).not_to permit(user, event)
        end
      end
    end

    context "system calendar event" do
      let(:calendar) { create(:your_meals_calendar) }
      let(:event) { build(:event, creator: creator, calendar: calendar) }

      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      permissions :new?, :create?, :edit?, :update?, :destroy? do
        it "forbids all" do
          expect(subject).not_to permit(creator, event)
          expect(subject).not_to permit(user, event)
          expect(subject).not_to permit(admin, event)
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
    let(:admin_attribs) { basic_attribs + %i[creator_id group_id] }
    let(:submitted_group_id) { nil }
    subject { Calendars::EventPolicy.new(user, event).permitted_attributes(group_id: submitted_group_id) }

    context "regular event" do
      let(:basic_attribs) do
        %i[name kind sponsor_id starts_at ends_at guidelines_ok note origin_page all_day]
      end

      context "regular user" do
        let(:user) { create(:user) }

        it "should allow basic attribs" do
          expect(subject).to contain_exactly(*basic_attribs)
        end

        context "when group_id is submitted" do
          let(:group) { create(:group, joiners: joiners) }
          let(:submitted_group_id) { group.id }

          context "when user is member of group" do
            let(:joiners) { [user] }

            it "should also allow group_id" do
              expect(subject).to contain_exactly(*basic_attribs + [:group_id])
            end
          end

          context "when user is not member of group" do
            let(:joiners) { [] }

            it "should not allow group_id" do
              expect(subject).to contain_exactly(*basic_attribs)
            end
          end
        end
      end

      shared_examples_for "admin or coord" do
        it "should allow admin-only attribs" do
          expect(subject).to contain_exactly(*admin_attribs)
        end

        context "when group_id is submitted" do
          let(:group) { create(:group, joiners: joiners) }
          let(:submitted_group_id) { group.id }

          context "when user is not member of group" do
            let(:joiners) { [] }

            it "should allow group_id anyway" do
              expect(subject).to contain_exactly(*admin_attribs)
            end
          end
        end
      end

      context "calendar_coordinator" do
        let(:user) { calendar_coordinator }
        it_behaves_like "admin or coord"
      end

      context "admin" do
        let(:user) { admin }
        it_behaves_like "admin or coord"
      end

      context "outside admin" do
        let(:user) { admin_cmtyB }

        it "should allow basic attribs" do
          expect(subject).to contain_exactly(*basic_attribs)
        end
      end
    end

    context "meal event" do
      let(:basic_attribs) { %i[starts_at ends_at note origin_page] }
      let(:meal) { create(:meal, calendars: [calendar]).tap(&:build_events) }
      let(:event) { meal.events[0] }

      context "regular user" do
        let(:user) { create(:user) }

        it "should allow nothing" do
          expect(subject).to be_empty
        end
      end

      context "calendar_coordinator" do
        let(:user) { calendar_coordinator }

        it "should basic attribs" do
          expect(subject).to contain_exactly(*basic_attribs)
        end
      end

      context "admin" do
        let(:user) { admin }

        it "should basic attribs" do
          expect(subject).to contain_exactly(*basic_attribs)
        end
      end

      context "outside admin" do
        let(:user) { admin_cmtyB }

        it "should allow nothing" do
          expect(subject).to be_empty
        end
      end
    end
  end
end
