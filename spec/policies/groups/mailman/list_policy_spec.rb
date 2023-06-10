# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::ListPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:communities) { [community, communityC] }
    let(:group) { create(:group, availability: "open", communities: communities) }
    let(:manager) { create(:group_membership, group: group, kind: "manager").user }
    let(:list) { build(:group_mailman_list, group: group) }
    let(:record) { list }

    shared_examples_for "permits active admins in group's communities but not regular users" do
      it do
        expect(subject).to permit(admin, list)
        expect(subject).not_to permit(admin_cmtyB, list)
        expect(subject).not_to permit(inactive_admin, list)
        expect(subject).to permit(cluster_admin_cmtyB, list)
        expect(subject).to permit(super_admin_cmtyX, list)
        expect(subject).not_to permit(user, list)
        expect(subject).not_to permit(user_cmtyC, list)
      end
    end

    permissions :edit? do
      it_behaves_like "permits active admins in group's communities but not regular users"
      it { is_expected.not_to permit(manager, list) }
    end

    permissions :edit_name? do
      it_behaves_like "permits active admins in group's communities but not regular users"
      it { is_expected.not_to permit(manager, list) }

      context "when list is not new record" do
        before { list.save! }
        it { is_expected.not_to permit(admin, list) }
      end
    end

    permissions :sync? do
      it "permits any user in any of the list's group's communities" do
        expect(subject).to permit(user, list)
        expect(subject).to permit(user_cmtyC, list)
        expect(subject).not_to permit(user_cmtyB, list)
      end
    end
  end
end
