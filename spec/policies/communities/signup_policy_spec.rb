# frozen_string_literal: true

require "rails_helper"

describe Communities::SignupPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:approver) { create(:user).tap { |u| u.add_role(:new_community_approver) } }
    let(:failed) { build(:communities_signup, :failed) }
    let(:creating) { build(:communities_signup, :creating) }

    permissions :retry? do
      it "permits approvers and super admins on failed signups" do
        expect(subject).to permit(approver, failed)
        expect(subject).to permit(super_admin, failed)
        expect(subject).not_to permit(cluster_admin, failed)
        expect(subject).not_to permit(admin, failed)
        expect(subject).not_to permit(user, failed)
      end

      it "forbids retrying a signup that hasn't failed" do
        expect(subject).not_to permit(approver, creating)
        expect(subject).not_to permit(approver, build(:communities_signup))
        expect(subject).not_to permit(approver, build(:communities_signup, status: "created"))
      end
    end
  end
end
