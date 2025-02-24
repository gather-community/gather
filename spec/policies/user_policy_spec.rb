# frozen_string_literal: true

require "rails_helper"

describe UserPolicy do
  describe "permissions" do
    include_context "policy permissions"
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
        expect(subject).to permit(actor, user_cmtyB)
      end
    end

    shared_examples_for "permits action on own community users but denies on all others" do
      it_behaves_like "permits action on own community"

      it "denies action on users in other community in cluster" do
        expect(subject).not_to permit(actor, user_cmtyB)
        expect(subject).not_to permit(actor, child_cmtyB)
      end

      it "denies action on users outside cluster" do
        expect(subject).not_to permit(actor, user_cmtyX)
        expect(subject).not_to permit(actor, child_cmtyX)
      end
    end

    shared_examples_for "permits action on cluster users except non-community children, denies on others" do
      it_behaves_like "permits action on own community and cluster community adults"

      it "denies action on children in other community in cluster" do
        expect(subject).not_to permit(actor, child_cmtyB)
      end

      it "denies action on users outside cluster" do
        expect(subject).not_to permit(actor, user_cmtyX)
        expect(subject).not_to permit(actor, child_cmtyX)
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
          expect(subject).to permit(actor, child_cmtyB)
        end

        it "denies action on users outside cluster" do
          expect(subject).not_to permit(actor, user_cmtyX)
          expect(subject).not_to permit(actor, child_cmtyX)
        end
      end

      context "for super admin" do
        let(:actor) { super_admin }
        it_behaves_like "permits action on own community and cluster community adults"

        it "permits action on children in other community in cluster" do
          expect(subject).to permit(actor, child_cmtyB)
        end

        it "permits action on users outside cluster" do
          expect(subject).to permit(actor, user_cmtyX)
          expect(subject).to permit(actor, child_cmtyX)
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
          user_cmtyB.privacy_settings["hide_photo_from_cluster"] = true
        end
        it_behaves_like "permits action on own community users but denies on all others"
      end

      it_behaves_like "cluster and super admins"
      it_behaves_like "inactive users"
    end

    permissions :new?, :create? do
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

      it "permits on other admins of same level" do
        expect(subject).to permit(admin, admin2)
        expect(subject).to permit(cluster_admin, cluster_admin2)
        expect(subject).to permit(super_admin, super_admin2)
      end

      it "denies for admins on higher admins" do
        expect(subject).not_to permit(admin, cluster_admin)
        expect(subject).not_to permit(admin, super_admin)
        expect(subject).not_to permit(cluster_admin, super_admin)
      end

      it "permits for full access children" do
        expect(subject).to permit(admin, full_access_child)
      end

      it "denies on non-full-access users" do
        expect(subject).not_to permit(admin, child)
      end
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins except self and guardians"
    end

    permissions :cluster_adminify? do
      it "permits action on cluster admin and above" do
        expect(subject).to permit(cluster_admin, user)
        expect(subject).to permit(super_admin, user)
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
      it_behaves_like "permits admins or special role but not regular users", :photographer
      it_behaves_like "permits self (active or not) and guardians"
    end

    permissions :update_photo? do
      it_behaves_like "permits special role but not regular users", "photographer"

      it "denies admins" do # Admins can do regular edit instead.
        expect(subject).not_to permit(admin, user)
      end
    end

    permissions :update_info?, :update_setting? do
      it_behaves_like "permits admins but not regular users"
      it_behaves_like "permits self (active or not) and guardians"
    end

    permissions :destroy? do
      let(:user) { create(:user) }
      let(:admin) { create(:admin) }
      let(:super_admin) { create(:super_admin) }
      let(:record) { create(:user) }

      context "with non-restricted associations" do
        let!(:proxier) { create(:user, job_choosing_proxy: record) }
        let!(:share) { create(:work_share, user: record) }
        let!(:membership) { create(:group_membership, user: record) }

        it_behaves_like "permits admins but not regular users"
      end

      context "with assignments" do
        let!(:assignment) { create(:work_assignment, user: record) }
        it_behaves_like "forbids all"
      end

      context "with child" do
        let!(:child) { create(:user, :child, guardians: [record]) }
        it_behaves_like "forbids all"
      end

      context "with guardian" do
        let(:record) { create(:user, :child) }
        it_behaves_like "forbids all"
      end

      context "with created meals" do
        let!(:meal) { create(:meal, creator: record) }
        it_behaves_like "forbids all"
      end

      context "with own events" do
        let!(:event) { create(:event, creator: record) }
        it_behaves_like "forbids all"
      end

      context "with sponsored events" do
        let!(:event) { create(:event, sponsor: record) }
        it_behaves_like "forbids all"
      end

      context "with wiki page creation" do
        let!(:page) { create(:wiki_page, creator: record) }
        it_behaves_like "forbids all"
      end

      context "with wiki page update" do
        let!(:page) { create(:wiki_page, updater: record) }
        it_behaves_like "forbids all"
      end

      context "with memorial" do
        let!(:memorial) { create(:memorial, user: record) }
        it_behaves_like "forbids all"
      end

      context "with memorial message" do
        let!(:memorial_message) { create(:memorial_message, author: record) }
        it_behaves_like "forbids all"
      end

      context "with wiki page version update" do
        let!(:page) { create(:wiki_page) }

        before do
          page.update!(content: "x", updater: record)
          page.update!(content: "y", updater: create(:user))
          # Only relation at this point should be to second page version
        end

        it_behaves_like "forbids all"
      end
    end
  end

  describe "#grantable_roles" do
    include_context "policy permissions"
    let(:roles) { described_class.new(actor, other_user).grantable_roles }
    let(:base_roles) do
      %i[biller calendar_coordinator photographer meals_coordinator wikiist work_coordinator]
    end

    context "for super admin" do
      let(:actor) { super_admin }
      it { expect(roles).to match_array(%i[super_admin cluster_admin admin] + base_roles) }
    end

    context "for cluster admin" do
      let(:actor) { cluster_admin }
      it { expect(roles).to match_array(%i[cluster_admin admin] + base_roles) }
    end

    context "for admin" do
      let(:actor) { admin }
      it { expect(roles).to match_array(%i[admin] + base_roles) }
    end

    context "for user with base role" do
      let(:actor) { biller }
      it { expect(roles).to be_empty }
    end

    context "for user with no role" do
      let(:actor) { user }
      it { expect(roles).to be_empty }
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { User }

    # If we don't specify guardians, a bunch of extra users get created by the factory.
    let(:child) { create(:user, :child, guardians: [user]) }
    let(:other_child) { create(:user, :child, guardians: [user]) }
    let(:inactive_child) { create(:user, :child, :inactive, guardians: [user]) }
    let(:childB) { create(:user, :child, guardians: [user], community: communityB) }

    context "for cluster admin" do
      let(:actor) { cluster_admin }

      it "returns adults and children in cluster including inactives" do
        is_expected.to contain_exactly(user, other_user, userB, inactive_user,
                                       admin, cluster_admin, child, inactive_child, other_child, childB)
      end
    end

    context "for admin" do
      let(:actor) { admin }

      it "includes inactive users" do
        is_expected.to contain_exactly(user, other_user, userB, admin, cluster_admin, child,
                                       other_child, inactive_user, inactive_child)
      end
    end

    context "for regular user" do
      let(:actor) { user }

      it "does not return inactive users" do
        is_expected.to contain_exactly(user, other_user, userB, admin, cluster_admin, child, other_child)
      end
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:user2) do
      double(community: community, cluster: cluster, guardians: [],
             household: double(community: community, cluster: cluster))
    end
    let(:base_attribs) do
      [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone,
       :child, :full_access, :certify_13_or_older, :paypal_email, :pronouns,
       :photo_new_signed_id, :photo_destroy, :birthday_str, :child, :joined_on, :preferred_contact,
       :job_choosing_proxy_id, :allergies, :doctor, :medical, :school, :household_by_id,
       {privacy_settings: [:hide_photo_from_cluster]},
       {up_guardianships_attributes: %i[id guardian_id _destroy]}]
    end
    let(:normal_user_attribs) do
      base_attribs + [
        {household_attributes: %i[id name garage_nums keyholders]
          .concat(nested_hhold_attribs)}
      ]
    end
    let(:photographer_attribs) { %i[photo_new_signed_id photo_destroy] }
    let(:admin_attribs) do
      base_attribs + [
        :google_email, :role_admin, :role_biller, :role_photographer,
        :role_calendar_coordinator, :role_meals_coordinator, :role_wikiist, :role_work_coordinator,
        {household_attributes: %i[id name garage_nums keyholders unit_num_and_suffix
                                  old_id old_name member_type_id]
          .concat(nested_hhold_attribs)}
      ]
    end
    let(:cluster_admin_attribs) do
      base_attribs + [
        :google_email, :role_cluster_admin, :role_admin, :role_biller, :role_photographer,
        :role_calendar_coordinator, :role_meals_coordinator, :role_wikiist, :role_work_coordinator,
        {household_attributes: %i[id name garage_nums keyholders unit_num_and_suffix
                                  old_id old_name member_type_id]
          .concat(nested_hhold_attribs)}
      ]
    end
    let(:nested_hhold_attribs) do
      [
        {vehicles_attributes: %i[id make model color plate _destroy]},
        {emergency_contacts_attributes: %i[id name relationship main_phone alt_phone
                                           email location country_code _destroy]},
        {pets_attributes: %i[id name species color vet caregivers health_issues _destroy]}
      ]
    end
    subject { UserPolicy.new(user, user2).permitted_attributes }

    shared_examples_for "normal user" do
      it "should allow normal user attribs" do
        expect(subject).to match_array(normal_user_attribs)
      end
    end

    context "normal user" do
      it_behaves_like "normal user"

      context "with custom fields defined on community" do
        let(:community_with_user_custom_fields) do
          create(:community, settings: {
            people: {
              user_custom_fields_spec: "- key: foo\n  type: string\n- key: bar\n  type: string"
            }
          })
        end
        let(:user) { create(:user, community: community_with_user_custom_fields) }
        let(:user2) { create(:user, community: community_with_user_custom_fields) }

        it "includes custom data fields in permitted attributes" do
          expect(subject).to match_array(normal_user_attribs << {custom_data: %i[foo bar]})
        end
      end
    end

    context "photographer" do
      let(:user) { photographer }

      it "should allow photographer attribs only" do
        expect(subject).to match_array(photographer_attribs)
      end
    end

    context "admin" do
      let(:user) { admin }

      it "should allow admin attribs" do
        expect(subject).to match_array(admin_attribs)
      end
    end

    context "admin from other community" do
      let(:user) { admin_cmtyB }
      it_behaves_like "normal user"
    end

    context "cluster admin" do
      let(:user) { cluster_admin }

      it "should allow cluster admin attribs" do
        expect(subject).to match_array(cluster_admin_attribs)
      end
    end

    context "super admin" do
      let(:user) { super_admin }

      it "should allow super admin attribs" do
        expect(subject).to match_array(cluster_admin_attribs << :role_super_admin)
      end
    end
  end

  describe "#exportable_attributes" do
    include_context "policy permissions"

    let(:sample_user) { double(community: community) }
    let(:base_attribs) do
      %i[id first_name last_name unit_num unit_suffix birthdate email child full_access
         household_id household_name pronouns
         guardian_names mobile_phone home_phone work_phone joined_on preferred_contact
         garage_nums vehicles keyholders emergency_contacts pets]
    end
    subject(:exportable) { described_class.new(actor, sample_user).exportable_attributes }

    context "for regular user" do
      let(:actor) { user }
      it { is_expected.to match_array(base_attribs) }
    end

    context "for admin" do
      let(:actor) { admin }
      it { is_expected.to match_array(base_attribs.concat(%i[google_email paypal_email deactivated_at])) }
    end
  end
end
