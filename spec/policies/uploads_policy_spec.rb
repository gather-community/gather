# frozen_string_literal: true

require "rails_helper"

describe UploadPolicy do
  describe "permissions" do
    include_context "policy permissions"

    permissions :create?, :destroy? do
      it "permits active users" do
        expect(subject).to permit(user, Upload)
      end

      it "forbids regular users" do
        expect(subject).not_to permit(inactive_user, Upload)
      end
    end
  end
end
