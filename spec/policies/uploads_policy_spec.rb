require 'rails_helper'

describe UploadPolicy do
  include_context "policy objs"

  describe "permissions" do
    permissions :create?, :destroy? do
      it "grants access to active users" do
        expect(subject).to permit(user, Upload)
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(inactive_user, Upload)
      end
    end
  end
end
