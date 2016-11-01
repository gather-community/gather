require 'rails_helper'

describe CalendarExportPolicy do
  describe "permissions" do
    include_context "policy objs"

    permissions :index?, :show?, :reset_token? do
      it "grants access to active users" do
        expect(subject).to permit(user, CalendarExport)
      end

      it "denies access to inactive users" do
        expect(subject).not_to permit(inactive_user, CalendarExport)
      end
    end
  end
end
