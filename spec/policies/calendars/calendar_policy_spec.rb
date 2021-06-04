# frozen_string_literal: true

require "rails_helper"

describe Calendars::CalendarPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:calendar) { create(:calendar) }
    let(:record) { calendar }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, :deactivate? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins but not regular users"
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
      let!(:group1) { create(:calendar_group) }
      let(:actor) { admin }

      it "exludes groups" do
        is_expected.to contain_exactly(calendar1)
      end
    end

    describe "#resolve_for_create" do
      let!(:calendar1) { create(:calendar, name: "Cal1") }
      let!(:calendar2) { create(:calendar, name: "Cal2") }
      let!(:calendar3) { create(:calendar, name: "Cal3") }
      let(:actor) { user }
      subject(:result) { described_class::Scope.new(actor, klass.by_name).resolve_for_create }

      it "returns calendars for which EventPolicy returns true" do
        expect(Calendars::EventPolicy).to receive(:new)
          .and_return(double(create?: true), double(create?: true), double(create?: false))
        expect(result).to eq([calendar1, calendar2])
      end
    end
  end

  describe "permitted attributes" do
    context "with normal calendar" do
      subject { Calendars::CalendarPolicy.new(User.new, Calendars::Calendar.new).permitted_attributes }

      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:default_calendar_view, :guidelines, :abbrv, :name, :color,
                                           :meal_hostable, :photo_new_signed_id, :photo_destroy, :group_id,
                                           :allow_overlap)
      end
    end

    context "with system calendar" do
      subject do
        Calendars::CalendarPolicy.new(User.new, Calendars::System::YourMealsCalendar.new).permitted_attributes
      end

      it "should allow fewer attribs" do
        expect(subject).to contain_exactly(:default_calendar_view, :abbrv, :name, :color,
                                           :photo_new_signed_id, :photo_destroy, :group_id)
      end
    end
  end
end
