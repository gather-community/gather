require 'rails_helper'

describe UserPolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:record) { other_user }

    shared_examples_for "own community and cluster community adults" do
      it "lets user perform action on adults in same community" do
        expect(subject).to permit(actor, other_user)
      end

      it "lets user perform action on children in same community" do
        expect(subject).to permit(actor, other_child)
      end

      it "lets user perform action on adults in other community in cluster" do
        expect(subject).to permit(actor, user_in_cluster)
      end

      it "lets user perform action on inactive users" do
        expect(subject).to permit(actor, inactive_user)
      end
    end

    shared_examples_for "cluster access except non-community children" do
      it_behaves_like "own community and cluster community adults"

      it "doesn't let user perform action on children in other community in cluster" do
        expect(subject).not_to permit(actor, child_in_cluster)
      end

      it "doesn't let user perform action on users outside cluster" do
        expect(subject).not_to permit(actor, outside_user)
        expect(subject).not_to permit(actor, outside_child)
      end
    end

    permissions :index? do
      it "grants access to active users" do
        expect(subject).to permit(user, User)
      end

      it "denies access to inactive users" do
        expect(subject).not_to permit(inactive_user, User)
      end
    end

    permissions :show? do
      context "for normal user" do
        let(:actor) { user }
        it_behaves_like "cluster access except non-community children"
      end

      context "for admin" do
        let(:actor) { admin }
        it_behaves_like "cluster access except non-community children"
      end

      context "for cluster admin" do
        let(:actor) { cluster_admin }
        it_behaves_like "own community and cluster community adults"

        it "lets user view children in other community in cluster" do
          expect(subject).to permit(actor, child_in_cluster)
        end

        it "doesn't let user view users outside cluster" do
          expect(subject).not_to permit(actor, outside_user)
          expect(subject).not_to permit(actor, outside_child)
        end
      end

      context "for super admin" do
        let(:actor) { super_admin }
        it_behaves_like "own community and cluster community adults"

        it "lets user view children in other community in cluster" do
          expect(subject).to permit(actor, child_in_cluster)
        end

        it "lets user view users outside cluster" do
          expect(subject).to permit(actor, outside_user)
          expect(subject).to permit(actor, outside_child)
        end
      end

      context "for inactive user" do
        it "doesn't let user view other users" do
          expect(subject).not_to permit(inactive_user, other_user)
        end

        it "lets user view self" do
          expect(subject).to permit(inactive_user, inactive_user)
        end
      end
    end

    permissions :new?, :create?, :invite?, :send_invites? do
      it_behaves_like "admins only"
    end

    permissions :activate?, :deactivate?, :administer?, :add_basic_role? do
      it_behaves_like "admins only"

      it "denies access to self" do
        expect(subject).not_to permit(user, user)
      end

      it "denies access to guardians for own children" do
        expect(subject).not_to permit(guardian, child)
      end
    end

    permissions :cluster_adminify? do
      it "grants access to cluster admin and above" do
        expect(subject).to permit(cluster_admin, user)
      end

      it "denies access to regular admins" do
        expect(subject).not_to permit(admin, user)
      end
    end

    permissions :super_adminify? do
      it "grants access to super admin" do
        expect(subject).to permit(super_admin, user)
      end

      it "denies access to cluster admins" do
        expect(subject).not_to permit(cluster_admin, user)
      end
    end

    permissions :edit?, :update? do
      it_behaves_like "admins only"

      it "grants access to self" do
        expect(subject).to permit(user, user)
      end

      it "allows guardians to edit own children" do
        expect(subject).to permit(guardian, child)
      end

      it "disallows guardians from editing other children" do
        expect(subject).not_to permit(guardian, other_child)
      end

      it "disallows children from editing parent" do
        expect(subject).not_to permit(child, guardian)
      end

      it "grants access to self for inactive user" do
        expect(subject).to permit(inactive_user, inactive_user)
      end
    end

    permissions :destroy? do
      shared_examples_for "full denial" do
        it "denies access to admins" do
          expect(subject).not_to permit(admin, user)
        end
      end

      context "with assignments" do
        before { allow(user).to receive(:any_assignments?).and_return(true) }
        it_behaves_like "full denial"
      end

      context "without assignment" do
        before { allow(user).to receive(:any_assignments?).and_return(false) }
        it_behaves_like "admins only"
      end
    end
  end

  describe "scope" do
    before do
      save_policy_objects!(cluster, clusterB, community, communityB, communityX,
        user, other_user, inactive_user, user_in_cluster, outside_user,
        admin, cluster_admin, super_admin,
        child, other_child, inactive_child, child_in_cluster, outside_child)
    end

    context "for super admin" do
      it "returns all users" do
        permitted = UserPolicy::Scope.new(super_admin, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cluster, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child, child_in_cluster,
          outside_user, outside_child)
      end
    end

    context "for cluster admin" do
      it "returns adults and children in cluster only" do
        permitted = UserPolicy::Scope.new(cluster_admin, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cluster, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child, child_in_cluster)
      end
    end

    context "for admin" do
      it "returns adults in cluster and children in community" do
        permitted = UserPolicy::Scope.new(admin, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cluster, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child)
      end
    end

    context "for regular user" do
      it "returns adults in cluster and children in community" do
        permitted = UserPolicy::Scope.new(user, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cluster, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child)
      end
    end
  end

  describe "permitted attributes" do
    let(:user2) { double(community: community, household: double(community: community)) }
    let(:basic_attribs) { [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone,
      :photo, :photo_tmp_id, :photo_destroy, :birthdate_str, :child, :joined_on, :preferred_contact,
      :household_by_id,
      {up_guardianships_attributes: [:id, :guardian_id, :_destroy]},
      {household_attributes: [:id, :name, :garage_nums].
        concat(vehicles_and_contacts_attribs)}
    ] }
    let(:admin_attribs) { [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone,
      :photo, :photo_tmp_id, :photo_destroy, :birthdate_str, :child, :joined_on, :preferred_contact,
      :google_email, :alternate_id, :role_admin, :role_biller, :household_by_id,
      {up_guardianships_attributes: [:id, :guardian_id, :_destroy]},
      {household_attributes: [:id, :name, :garage_nums, :unit_num, :old_id, :old_name].
        concat(vehicles_and_contacts_attribs)}
    ] }
    let(:cluster_admin_attribs) { [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone,
      :photo, :photo_tmp_id, :photo_destroy, :birthdate_str, :child, :joined_on, :preferred_contact,
      :google_email, :alternate_id, :role_cluster_admin, :role_admin, :role_biller, :household_by_id,
      {up_guardianships_attributes: [:id, :guardian_id, :_destroy]},
      {household_attributes: [:id, :name, :garage_nums, :unit_num, :old_id, :old_name].
        concat(vehicles_and_contacts_attribs)}
    ] }
    let(:vehicles_and_contacts_attribs) { [
      {vehicles_attributes: [:id, :make, :model, :color, :_destroy]},
      {emergency_contacts_attributes: [:id, :name, :relationship, :main_phone, :alt_phone,
        :email, :location, :_destroy]}
    ] }
    subject { UserPolicy.new(user, user2).permitted_attributes }

    shared_examples_for "basic attribs" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(*basic_attribs)
      end
    end

    context "regular user" do
      it_behaves_like "basic attribs"
    end

    context "admin" do
      let(:user) { admin }

      it "should allow admin attribs" do
        expect(subject).to contain_exactly(*(admin_attribs))
      end
    end

    context "admin from other community" do
      let(:user) { admin_in_cluster }
      it_behaves_like "basic attribs"
    end

    context "cluster admin" do
      let(:user) { cluster_admin }

      it "should allow cluster admin attribs" do
        expect(subject).to contain_exactly(*cluster_admin_attribs)
      end
    end

    context "super admin" do
      let(:user) { super_admin }

      it "should allow super admin attribs" do
        expect(subject).to contain_exactly(*(cluster_admin_attribs << :role_super_admin))
      end
    end
  end
end
