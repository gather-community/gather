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
        calendar.save!
        create(:event, calendar: calendar)
        expect(subject).not_to permit(admin, calendar)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Calendars::Calendar }
    let!(:calendar1) { create(:calendar) }
    let!(:group1) { create(:calendar_group) }
    let(:actor) { admin }

    it "exludes groups" do
      is_expected.to contain_exactly(calendar1)
    end
  end

  describe "permitted attributes" do
    subject { Calendars::CalendarPolicy.new(User.new, Calendars::Calendar.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:default_calendar_view, :guidelines, :abbrv, :name,
                                         :meal_hostable, :photo_new_signed_id, :photo_destroy, :group_id)
    end
  end
end
