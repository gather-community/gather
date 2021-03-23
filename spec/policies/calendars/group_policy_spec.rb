# frozen_string_literal: true

require "rails_helper"

describe Calendars::GroupPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:group) { create(:calendar_group) }
    let(:record) { group }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins but not regular users"
    end
  end

  describe "permitted attributes" do
    subject do
      Calendars::GroupPolicy.new(User.new, Calendars::Group.new).permitted_attributes
    end

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:name)
    end
  end
end
