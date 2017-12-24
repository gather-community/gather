require 'rails_helper'

describe UserPolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:record) { other_user }

    shared_examples_for "permits action on own community" do
      it "permits action on adults in same community" do
        expect(subject).to permit(actor, other_user)
      end

      it "permits action on children in same community" do
        expect(subject).to permit(actor, other_child)
      end

      it "permits action on inactive users" do
        expect(subject).to permit(actor, inactive_user)
      end
    end

    shared_examples_for "permits action on own community and cluster community adults" do
      it_behaves_like "permits action on own community"

      it "permits action on adults in other community in cluster" do
        expect(subject).to permit(actor, user_in_cmtyB)
      end
    end

    shared_examples_for "permits action on own community users but denies on all others" do
      it_behaves_like "permits action on own community"

      it "denies action on users in other community in cluster" do
        expect(subject).not_to permit(actor, user_in_cmtyB)
        expect(subject).not_to permit(actor, child_in_cmtyB)
      end

      it "denies action on users outside cluster" do
        expect(subject).not_to permit(actor, outside_user)
        expect(subject).not_to permit(actor, outside_child)
      end
    end

    shared_examples_for "permits action on cluster users except non-community children, denies on others" do
      it_behaves_like "permits action on own community and cluster community adults"

      it "denies action on children in other community in cluster" do
        expect(subject).not_to permit(actor, child_in_cmtyB)
      end

      it "denies action on users outside cluster" do
        expect(subject).not_to permit(actor, outside_user)
        expect(subject).not_to permit(actor, outside_child)
      end
    end

    shared_examples_for "inactive users" do
      context "for inactive user" do
        let(:actor) { inactive_user }

        it "denies action on other users" do
          expect(subject).not_to permit(actor, other_user)
        end

        it "permits action on self" do
          expect(subject).to permit(actor, actor)
        end
      end
    end

    shared_examples_for "cluster and super admins" do
      context "for cluster admin" do
        let(:actor) { cluster_admin }
        it_behaves_like "permits action on own community and cluster community adults"

        it "permits action on children in other community in cluster" do
          expect(subject).to permit(actor, child_in_cmtyB)
        end

        it "denies action on users outside cluster" do
          expect(subject).not_to permit(actor, outside_user)
          expect(subject).not_to permit(actor, outside_child)
        end
      end

      context "for super admin" do
        let(:actor) { super_admin }
        it_behaves_like "permits action on own community and cluster community adults"

        it "permits action on children in other community in cluster" do
          expect(subject).to permit(actor, child_in_cmtyB)
        end

        it "permits action on users outside cluster" do
          expect(subject).to permit(actor, outside_user)
          expect(subject).to permit(actor, outside_child)
        end
      end
    end

    shared_examples_for "permits admins except self and guardians" do
      it_behaves_like "permits admins but not regular users"

      it "denies action on self" do
        expect(subject).not_to permit(user, user)
      end

      it "denies action on guardians for own children" do
        expect(subject).not_to permit(guardian, child)
      end
    end

    permissions :index? do
      it "permits action on active users" do
        expect(subject).to permit(user, User)
      end

      it "denies action on inactive users" do
        expect(subject).not_to permit(inactive_user, User)
      end
    end

    permissions :show? do
      context "for normal user" do
        let(:actor) { user }
        it_behaves_like "permits action on cluster users except non-community children, denies on others"
      end

      context "for admin" do
        let(:actor) { admin }
        it_behaves_like "permits action on cluster users except non-community children, denies on others"
      end

      it_behaves_like "cluster and super admins"
      it_behaves_like "inactive users"
    end

    permissions :show_personal_info? do
      context "for normal user" do
        let(:actor) { user }
        it_behaves_like "permits action on own community users but denies on all others"
      end

      context "for admin" do
        let(:actor) { admin }
        it_behaves_like "permits action on own community users but denies on all others"
      end

      it_behaves_like "cluster and super admins"
      it_behaves_like "inactive users"
    end

    permissions :show_photo? do
      context "for normal user without flag set on target" do
        let(:actor) { user }
        it_behaves_like "permits action on cluster users except non-community children, denies on others"
      end

      context "for normal user with flag set to hide on target" do
        let(:actor) { user }
        before do
          user_in_cmtyB.privacy_settings["hide_photo_from_cluster"] = true
        end
        it_behaves_like "permits action on own community users but denies on all others"
      end

      it_behaves_like "cluster and super admins"
      it_behaves_like "inactive users"
    end

    permissions :new?, :create?, :invite?, :send_invites? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :deactivate?, :show_inactive?, :administer?, :add_basic_role? do
      it_behaves_like "permits admins except self and guardians"
    end

    permissions :impersonate? do
      it_behaves_like "permits admins but not regular users"

      it "denies on self" do
        expect(subject).not_to permit(admin, admin)
      end

      it "denies on other admins" do
        expect(subject).not_to permit(admin, admin2)
        expect(subject).not_to permit(admin, cluster_admin)
        expect(subject).not_to permit(admin, super_admin)
      end
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins except self and guardians"
    end

    permissions :cluster_adminify? do
      it "permits action on cluster admin and above" do
        expect(subject).to permit(cluster_admin, user)
      end

      it "denies action on regular admins" do
        expect(subject).not_to permit(admin, user)
      end
    end

    permissions :super_adminify? do
      it "permits action on super admin" do
        expect(subject).to permit(super_admin, user)
      end

      it "denies action on cluster admins" do
        expect(subject).not_to permit(cluster_admin, user)
      end
    end

    permissions :edit?, :update? do
      it_behaves_like "permits admins or special role but not regular users", "photographer"
      it_behaves_like "permits self (active or not) and guardians"
    end

    permissions :update_photo? do
      it_behaves_like "permits special role but not regular users", "photographer"

      it "denies admins" do # Admins can do regular edit instead.
        expect(subject).not_to permit(admin, user)
      end
    end

    permissions :update_info? do
      it_behaves_like "permits admins but not regular users"
      it_behaves_like "permits self (active or not) and guardians"
    end

    permissions :destroy? do
      shared_examples_for "full denial" do
        it "denies action on admins" do
          expect(subject).not_to permit(admin, user)
        end
      end

      context "with assignments" do
        before { allow(user).to receive(:any_assignments?).and_return(true) }
        it_behaves_like "full denial"
      end

      context "without assignment" do
        before { allow(user).to receive(:any_assignments?).and_return(false) }
        it_behaves_like "permits admins but not regular users"
      end
    end
  end

  describe "scope" do
    before do
      save_policy_objects!(cluster, clusterB, community, communityB, communityX,
        user, other_user, inactive_user, user_in_cmtyB, outside_user,
        admin, cluster_admin, super_admin,
        child, other_child, inactive_child, child_in_cmtyB, outside_child)
    end

    context "for super admin" do
      it "returns all users" do
        # This query crosses a tenant boundary so need to do it unscoped.
        ActsAsTenant.unscoped do
          permitted = UserPolicy::Scope.new(super_admin, User.all).resolve
          expect(permitted).to contain_exactly(user, other_user, user_in_cmtyB, inactive_user,
            admin, cluster_admin, super_admin, child, inactive_child, other_child, child_in_cmtyB,
            outside_user, outside_child)
        end
      end
    end

    context "for cluster admin" do
      it "returns adults and children in cluster only" do
        permitted = UserPolicy::Scope.new(cluster_admin, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cmtyB, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child, child_in_cmtyB)
      end
    end

    context "for admin" do
      it "returns adults in cluster and children in community" do
        permitted = UserPolicy::Scope.new(admin, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cmtyB, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child)
      end
    end

    context "for regular user" do
      it "returns adults in cluster and children in community" do
        permitted = UserPolicy::Scope.new(user, User.all).resolve
        expect(permitted).to contain_exactly(user, other_user, user_in_cmtyB, inactive_user,
          admin, cluster_admin, super_admin, child, inactive_child, other_child)
      end
    end
  end

  describe "permitted attributes" do
    let(:user2) { double(community: community, guardians: [], household: double(community: community)) }
    let(:base_attribs) { [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone,
      :photo, :photo_tmp_id, :photo_destroy, :birthdate_str, :child, :joined_on, :preferred_contact,
      :allergies, :doctor, :medical, :school, :household_by_id,
      {privacy_settings: [:hide_photo_from_cluster]},
      {up_guardianships_attributes: [:id, :guardian_id, :_destroy]}
    ] }
    let(:normal_user_attribs) { base_attribs + [
      {household_attributes: [:id, :name, :garage_nums, :keyholders].
        concat(nested_hhold_attribs)}
    ] }
    let(:photographer_attribs) { [:photo, :photo_tmp_id] }
    let(:admin_attribs) { base_attribs + [
      :google_email, :role_admin, :role_biller, :role_photographer,
      :role_meals_coordinator,
      {household_attributes: [:id, :name, :garage_nums, :keyholders, :unit_num, :old_id, :old_name].
        concat(nested_hhold_attribs)}
    ] }
    let(:cluster_admin_attribs) { base_attribs + [
      :google_email, :role_cluster_admin, :role_admin, :role_biller, :role_photographer,
      :role_meals_coordinator,
      {household_attributes: [:id, :name, :garage_nums, :keyholders, :unit_num, :old_id, :old_name].
        concat(nested_hhold_attribs)}
    ] }
    let(:nested_hhold_attribs) { [
      {vehicles_attributes: [:id, :make, :model, :color, :plate, :_destroy]},
      {emergency_contacts_attributes: [:id, :name, :relationship, :main_phone, :alt_phone,
        :email, :location, :_destroy]},
      {pets_attributes: [:id, :name, :species, :color, :vet, :caregivers, :health_issues, :_destroy]}
    ] }
    subject { UserPolicy.new(user, user2).permitted_attributes }

    shared_examples_for "normal user" do
      it "should allow normal user attribs" do
        expect(subject).to contain_exactly(*normal_user_attribs)
      end
    end

    context "normal user" do
      it_behaves_like "normal user"
    end

    context "photographer" do
      let(:user) { photographer }

      it "should allow photographer attribs only" do
        expect(subject).to contain_exactly(*photographer_attribs)
      end
    end

    context "admin" do
      let(:user) { admin }

      it "should allow admin attribs" do
        expect(subject).to contain_exactly(*admin_attribs)
      end
    end

    context "admin from other community" do
      let(:user) { admin_in_cmtyB }
      it_behaves_like "normal user"
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
