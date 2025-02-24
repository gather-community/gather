# frozen_string_literal: true

require "rails_helper"

describe Groups::GroupPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:availability) { "open" }
    let(:communities) { [community, communityC] }
    let(:group) { create(:group, availability: availability, communities: communities) }
    let(:record) { group }
    let(:manager) { create(:group_membership, group: group, kind: "manager").user }
    let(:other_group_manager) { create(:group_membership, kind: "manager").user }
    let(:joiner) { create(:group_membership, group: group, kind: "joiner").user }
    let(:opt_out) { create(:group_membership, group: group, kind: "opt_out").user }

    shared_examples_for "permits active admins in group's communities but not regular users" do
      it do
        expect(subject).to permit(admin, group)
        expect(subject).not_to permit(admin_cmtyB, group)
        expect(subject).not_to permit(inactive_admin, group)
        expect(subject).to permit(cluster_admin_cmtyB, group)
        expect(subject).to permit(super_admin_cmtyX, group)
        expect(subject).not_to permit(user, group)
        expect(subject).not_to permit(user_cmtyC, group)
      end
    end

    shared_examples_for "permits managers but not joiners or opt outs" do
      it do
        expect(subject).to permit(manager, group)
        expect(subject).not_to permit(other_group_manager, group)
        expect(subject).not_to permit(joiner, group)
        expect(subject).not_to permit(opt_out, group)
      end
    end

    permissions :index? do
      it_behaves_like "permits active users only"
    end

    permissions :show? do
      context "for most availabilities, e.g. closed" do
        let(:availability) { "closed" }

        it "permits any user" do
          expect(subject).to permit(user, group)
          expect(subject).to permit(user_cmtyC, group)
          expect(subject).to permit(user_cmtyB, group)
        end
      end

      context "for hidden group" do
        let(:availability) { "hidden" }
        it_behaves_like "permits active admins in group's communities but not regular users"
        it_behaves_like "permits managers but not joiners or opt outs"
      end
    end

    permissions :new?, :create? do
      it_behaves_like "permits active admins in group's communities but not regular users"
    end

    permissions :edit?, :update? do
      it_behaves_like "permits active admins in group's communities but not regular users"
      it_behaves_like "permits managers but not joiners or opt outs"
    end

    permissions :deactivate?, :destroy?, :change_permissions? do
      it_behaves_like "permits active admins in group's communities but not regular users"
      it { is_expected.not_to permit(manager, group) }
    end

    permissions :activate? do
      let(:group) { create(:group, :inactive, availability: availability, communities: communities) }
      it_behaves_like "permits active admins in group's communities but not regular users"
      it { is_expected.not_to permit(manager, group) }
    end

    # This permission does not depend on user role. It just depends on the user's membership type
    # and group availability. An admin can technically add themselves to a closed list, but that would
    # be via the edit screen, and not via this permission.
    permissions :join? do
      let!(:membership) { create(:group_membership, group: group, user: user, kind: mbr_kind) if mbr_kind }

      context "with everybody group" do
        let(:availability) { "everybody" }

        context "with user with no membership" do
          let(:mbr_kind) { nil }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with manager membership" do
          let(:mbr_kind) { "manager" }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with opt-out membership" do
          let(:mbr_kind) { "opt_out" }
          it { expect(subject).to permit(user, group) }
        end
      end

      context "with closed/hidden group" do
        let(:availability) { "closed" }

        context "with user with no membership" do
          let(:mbr_kind) { nil }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with manager membership" do
          let(:mbr_kind) { "manager" }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with joiner membership" do
          let(:mbr_kind) { "joiner" }
          it { expect(subject).not_to permit(user, group) }
        end
      end

      context "with open group" do
        let(:availability) { "open" }

        context "with user with no membership" do
          let(:mbr_kind) { nil }
          it { expect(subject).to permit(user, group) }
        end

        context "with user with manager membership" do
          let(:mbr_kind) { "manager" }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with joiner membership" do
          let(:mbr_kind) { "joiner" }
          it { expect(subject).not_to permit(user, group) }
        end
      end

      context "with group not affiliated with own community" do
        let(:mbr_kind) { nil }
        let(:communities) { [communityC] }
        it { expect(subject).not_to permit(user, group) }
      end
    end

    # This permission does not depend on user role. It just depends on the user's membership type
    # and group availability. An admin can technically add themselves to a closed list, but that would
    # be via the edit screen, and not via this permission.
    permissions :leave? do
      let!(:membership) { create(:group_membership, group: group, user: user, kind: mbr_kind) if mbr_kind }

      context "with everybody group" do
        let(:availability) { "everybody" }

        context "with user with no membership" do
          context "with group tied to own community" do
            let(:mbr_kind) { nil }
            it { expect(subject).to permit(user, group) }
          end

          context "with group not tied to own community" do
            let(:mbr_kind) { nil }
            let(:communities) { [communityC] }
            it { expect(subject).not_to permit(user, group) }
          end
        end

        context "with user with manager membership" do
          let(:mbr_kind) { "manager" }
          it { expect(subject).to permit(user, group) }
        end

        context "with user with opt-out membership" do
          let(:mbr_kind) { "opt_out" }
          it { expect(subject).not_to permit(user, group) }
        end
      end

      context "with closed/hidden group" do
        let(:availability) { "closed" }

        context "with user with no membership" do
          let(:mbr_kind) { nil }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with manager membership" do
          let(:mbr_kind) { "manager" }
          it { expect(subject).to permit(user, group) }
        end

        context "with user with joiner membership" do
          let(:mbr_kind) { "joiner" }
          it { expect(subject).to permit(user, group) }
        end
      end

      context "with open group" do
        let(:availability) { "open" }

        context "with user with no membership" do
          let(:mbr_kind) { nil }
          it { expect(subject).not_to permit(user, group) }
        end

        context "with user with manager membership" do
          let(:mbr_kind) { "manager" }
          it { expect(subject).to permit(user, group) }
        end

        context "with user with joiner membership" do
          let(:mbr_kind) { "joiner" }
          it { expect(subject).to permit(user, group) }
        end
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Groups::Group }
    let!(:cluster_group) { create(:group, communities: [communityB]) }
    let!(:cmty_group) { create(:group, communities: [community, communityB]) }
    let!(:hidden_group) { create(:group, communities: [community], availability: "hidden") }
    let!(:inactive_group) { create(:group, :inactive, communities: [community]) }

    context "for cluster admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(cluster_group, cmty_group, hidden_group, inactive_group) }
    end

    context "for admin" do
      let(:actor) { admin }
      it { is_expected.to contain_exactly(cmty_group, hidden_group, inactive_group) }
    end

    context "for manager of hidden group" do
      let!(:actor) { create(:group_membership, group: hidden_group, kind: "manager").user }
      it { is_expected.to contain_exactly(cmty_group, hidden_group, cluster_group) }
    end

    context "for joiner of hidden group" do
      let!(:actor) { create(:group_membership, group: hidden_group, kind: "joiner").user }
      it { is_expected.to contain_exactly(cmty_group, cluster_group) }
    end

    context "for regular user" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(cmty_group, cluster_group) }
    end

    context "for inactive user" do
      let(:actor) { inactive_user }
      it { is_expected.to be_empty }
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"

    let(:base_attribs) do
      %i[availability description kind name] <<
        {memberships_attributes: %i[id kind user_id _destroy]}
    end
    let(:list_attribs) do
      [mailman_list_attributes: %i[managers_can_administer managers_can_moderate id _destroy]]
    end
    let(:list_attribs_with_name_edit) do
      [mailman_list_attributes: %i[managers_can_administer managers_can_moderate
                                   id _destroy name domain_id]]
    end
    let(:permission_attribs) { %i[can_request_jobs can_administer_email_lists can_moderate_email_lists] }
    let(:base_admin_attribs) { base_attribs.concat(permission_attribs).concat(list_attribs) }
    let(:group) { create(:group) }
    let!(:list) { create(:group_mailman_list, group: group) }
    subject { Groups::GroupPolicy.new(actor, group).permitted_attributes }

    before { group.reload unless group.new_record? }

    context "with super admin" do
      let(:actor) { super_admin }
      it { is_expected.to match_array(base_admin_attribs << {community_ids: []}) }
    end

    context "with cluster admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to match_array(base_admin_attribs << {community_ids: []}) }
    end

    context "with admin" do
      let(:actor) { admin }

      context "with persisted record" do
        it { is_expected.to match_array(base_admin_attribs) }
      end

      context "with new record" do
        let(:group) { build(:group) }

        # We should have ability to create list even if no list exists!
        let!(:list) { nil }
        let(:list_attribs) { list_attribs_with_name_edit }

        it { is_expected.to match_array(base_admin_attribs) }
      end
    end

    context "with manager" do
      let(:actor) { create(:group_membership, group: group, kind: "manager").user }
      it { is_expected.to match_array(base_attribs) }
    end
  end
end
