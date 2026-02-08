# frozen_string_literal: true

require "rails_helper"

describe Calendars::CalendarPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:calendar) { create(:calendar) }
    let(:record) { calendar }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, :deactivate? do
      it_behaves_like "permits admins or special role but not regular users", :calendar_coordinator
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins or special role but not regular users", :calendar_coordinator
    end

    permissions :destroy? do
      it "denies if there are existing events" do
        create(:event, calendar: calendar)
        expect(subject).not_to permit(admin, calendar)
      end

      context "with system calendar" do
        let(:calendar) { create(:your_meals_calendar) }

        it "denies" do
          expect(subject).not_to permit(admin, calendar)
        end
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Calendars::Calendar }

    describe "#resolve" do
      let!(:calendar1) { create(:calendar) }
      let!(:calendar2) { create(:community_meals_calendar) }
      let!(:group1) { create(:calendar_group) }
      let(:actor) { admin }

      it "exludes groups and includes subclasses" do
        is_expected.to contain_exactly(calendar1, calendar2)
      end
    end

    describe "#resolve_for_create" do
      let!(:calendar1) { create(:calendar) }
      let!(:group1) { create(:calendar_group) }
      let!(:calendar2) { create(:calendar, community: communityB) }
      let!(:calendar3) { create(:calendar, community: communityB) }
      let!(:calendar4) { create(:calendar, community: communityB) }
      let!(:calendar5) { create(:calendar, :inactive) }
      let!(:protocol1) { create(:calendar_protocol, calendars: [calendar3], other_communities: "forbidden") }
      let!(:protocol2) { create(:calendar_protocol, calendars: [calendar4], other_communities: "read_only") }

      let(:actor) { user }
      subject(:result) { described_class::Scope.new(actor, klass.by_name).resolve_for_create }

      context "for regular users" do
        let(:actor) { user }
        it "returns writeable calendars for regular users" do
          expect(result).to eq([calendar1, calendar2])
        end
      end

      context "for admins" do
        let(:actor) { cluster_admin }
        it "returns writeable calendars for cluster-admins" do
          expect(result).to eq([calendar1, calendar2, calendar3, calendar4])
        end
      end
    end
  end

  describe "permitted attributes" do
    context "with normal calendar" do
      subject { Calendars::CalendarPolicy.new(User.new, Calendars::Calendar.new).permitted_attributes }

      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:default_calendar_view, :guidelines, :abbrv, :name, :color,
                                           :meal_hostable, :photo_new_signed_id, :photo_destroy, :group_id,
                                           :allow_overlap, :selected_by_default)
      end
    end

    context "with system calendar" do
      subject do
        Calendars::CalendarPolicy.new(User.new, Calendars::System::YourMealsCalendar.new).permitted_attributes
      end

      it "should allow fewer attribs" do
        expect(subject).to contain_exactly(:default_calendar_view, :abbrv, :name, :color,
                                           :photo_new_signed_id, :photo_destroy, :group_id,
                                           :selected_by_default)
      end
    end
  end
end
