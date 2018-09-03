# frozen_string_literal: true

require "rails_helper"

describe CalendarExportPolicy do
  describe "permissions" do
    include_context "policy permissions"

    permissions :index?, :show?, :reset_token? do
      it "permits active users" do
        expect(subject).to permit(user, CalendarExport)
      end

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, CalendarExport)
      end
    end
  end
end
