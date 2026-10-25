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

    shared_examples_for "permits creator or group member but not regular users" do
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

      it "forbids regular users" do
        expect(subject).not_to permit(user, event)
      end
    end

    shared_examples_for "permits admins or calendar coord or creator or group member but not regular users" do
      it_behaves_like "permits admins or special role but not regular users", :calendar_coordinator
      it_behaves_like "permits creator or group member but not regular users"
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
    end

    context "regular (non-meal) event" do
      permissions :index?, :new?, :create? do
        it_behaves_like "permits active users only"
      end

      permissions :show? do
        it_behaves_like "permits active users only"

        context "all eventlets are forbidden" do
          let!(:calendar) { create(:calendar, community: communityB) }
          let!(:protocol) { create(:calendar_protocol, calendars: [calendar], other_communities: "forbidden") }

          it "forbids" do
            expect(subject).not_to permit(user, event)
          end
        end
      end

      permissions :edit?, :update? do
        context "when there are no eventlets" do
          before { event.eventlets.destroy_all }

          it { is_expected.not_to permit(admin, event) }
        end

        context "when all eventlets are editable" do
          it { is_expected.to permit(admin, event) }
        end

        context "when some eventlets are not editable" do
          let!(:forbidden_calendar) { create(:calendar, community: communityB) }
          let!(:protocol) do
            create(:calendar_protocol, calendars: [forbidden_calendar], other_communities: "forbidden")
          end
          let!(:eventlet) { create(:eventlet, event: event, calendar: forbidden_calendar) }

          it { is_expected.not_to permit(admin, event) }
        end
      end


      permissions :destroy? do
        context "when there are no eventlets" do
          before { event.eventlets.destroy_all }

          it { is_expected.not_to permit(admin, event) }
        end

        context "when all eventlets are destroyable" do
          it { is_expected.to permit(admin, event) }
        end

        context "when some eventlets are not destroyable" do
          let!(:forbidden_calendar) { create(:calendar, community: communityB) }
          let!(:protocol) do
            create(:calendar_protocol, calendars: [forbidden_calendar], other_communities: "forbidden")
          end
          let!(:eventlet) { create(:eventlet, event: event, calendar: forbidden_calendar) }

          it { is_expected.not_to permit(admin, event) }
        end
      end
    end

    context "event with calendar in different community and access_level rule for outside communities" do
      let(:calendar) { create(:calendar, community: communityB) }
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar], other_communities: access_level) }

      context "with forbidden access_level" do
        let(:access_level) { "forbidden" }

        permissions :show?, :edit?, :update?, :destroy? do
          it_behaves_like "permits cluster admins only"
        end
      end

      context "with read_only access_level" do
        let(:access_level) { "read_only" }

        permissions :show? do
          it_behaves_like "permits active users only"
        end

        permissions :edit?, :update?, :destroy? do
          it_behaves_like "permits cluster admins only"
        end
      end

      # For authz purposes, sponsor access level is treated the same as having no rule
      context "with sponsor access_level" do
        let(:access_level) { "sponsor" }

        permissions :show? do
          it_behaves_like "permits active users only"
        end

        permissions :edit?, :update?, :destroy? do
          it_behaves_like "permits cluster and super admins"
          it_behaves_like "permits creator or group member but not regular users"
        end
      end
    end

    context "meal event" do
      let(:meal) { create(:meal, calendars: [calendar]) }
      let(:event) { create(:event, creator: nil, calendar: calendar, meal: meal, starts_at: meal.served_at, ends_at: meal.served_at + 1.hour, kind: "_meal") }

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
