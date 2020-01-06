# frozen_string_literal: true

require "rails_helper"

describe SingleSignOnPolicy do
  describe "permissions" do
    include_context "policy permissions"

    permissions :sign_on? do
      it "permits active users" do
        expect(subject).to permit(user, Upload)
      end

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, Upload)
      end
    end
  end
end
