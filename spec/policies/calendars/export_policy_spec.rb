# frozen_string_literal: true

require "rails_helper"

describe Calendars::ExportPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { Calendars::Exports::Export.new(user: user) }

    permissions :index?, :show?, :reset_token? do
      it "permits active users" do
        expect(subject).to permit(user, record)
      end

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, record)
      end
    end
  end
end
