# frozen_string_literal: true

require "rails_helper"

describe Admin::HomePolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { %i[admin home] }
    let(:approver) { create(:user).tap { |u| u.add_role(:new_community_approver) } }

    permissions :show? do
      it "permits anyone who can see an operator page" do
        expect(subject).to permit(super_admin, record)
        expect(subject).to permit(approver, record)
        expect(subject).not_to permit(cluster_admin, record)
        expect(subject).not_to permit(admin, record)
        expect(subject).not_to permit(user, record)
      end
    end
  end
end
