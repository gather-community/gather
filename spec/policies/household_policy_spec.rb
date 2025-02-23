# frozen_string_literal: true

require "rails_helper"

describe HouseholdPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:record) { household }

    shared_examples_for "permits admins and members of household" do
      # We don't need to check cluster admins/super admins here or in every other place where
      # admin permissions are tested. We are trusting the active_admin? method which is tested elsewhere.
      it "permits admins" do
        expect(subject).to permit(admin, record)
      end

      it "grants access for regular users to own household" do
        expect(subject).to permit(user, user.household)
      end

      it "forbids regular users to other households" do
        expect(subject).not_to permit(user, Household.new)
      end
    end

    shared_examples_for "permits action on own community" do
      it "permits action on households in same community" do
        expect(subject).to permit(user, other_user.household)
      end

      it "permits action on inactive households" do
        expect(subject).to permit(user, inactive_household)
      end
    end

    shared_examples_for "permits action on own cluster but not outside" do
      it_behaves_like "permits action on own community"

      it "permits action on households in other community in cluster" do
        expect(subject).to permit(user, user_cmtyB.household)
      end

      it "permits outside super admins" do
        expect(subject).to permit(super_admin_cmtyX, user_cmtyB.household)
      end

      it "denies action on households outside cluster" do
        expect(subject).not_to permit(user, user_cmtyX.household)
      end
    end

    shared_examples_for "permits action on own community users but denies on all others" do
      it_behaves_like "permits action on own community"

      it "denies action on households in other community in cluster" do
        expect(subject).not_to permit(user, user_cmtyB.household)
      end

      it "denies action on households outside cluster" do
        expect(subject).not_to permit(user, user_cmtyX.household)
      end
    end

    permissions :index?, :show? do
      it_behaves_like "permits action on own cluster but not outside"
    end

    permissions :show_personal_info? do
      it_behaves_like "permits action on own community users but denies on all others"
    end

    permissions :new?, :create?, :deactivate?, :administer? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins but not regular users"
    end

    permissions :edit?, :update? do
      it_behaves_like "permits admins and members of household"

      it "forbids billers" do
        expect(subject).not_to permit(biller, user.household)
      end
    end

    permissions :change_community? do
      it_behaves_like "permits cluster admins only"
    end

    permissions :destroy? do
      let(:user) { create(:user) }
      let(:admin) { create(:admin) }
      let(:super_admin) { create(:super_admin) }
      let(:household) { create(:household, skip_listener_action: :account_create) }

      context "with no restrictions" do
        it_behaves_like "permits admins but not regular users"
      end

      context "with non-deletable user" do
        let!(:event) { create(:event, creator: household.users[0]) }
        it_behaves_like "forbids all"
      end

      context "with signup" do
        let!(:signup) { create(:meal_signup, household: household, diner_counts: [2, 1]) }
        it_behaves_like "forbids all"
      end

      context "with account" do
        let!(:account) { create(:account, household: household) }
        it_behaves_like "forbids all"
      end
    end
  end

  describe "allowed_community_changes" do
    include_context "policy permissions"

    # Class-based auth not allowed
    let(:sample_household) { Household.new(community: community) }

    before do
      communityB && communityX # Force these to be created.
    end

    it "returns empty set for regular users" do
      expect(HouseholdPolicy.new(user, sample_household).allowed_community_changes.to_a).to eq([])
    end

    it "returns own community for admins" do
      expect(HouseholdPolicy.new(admin, sample_household).allowed_community_changes.to_a).to(
        contain_exactly(community)
      )
    end

    it "returns cluster communities for cluster admins" do
      expect(HouseholdPolicy.new(cluster_admin, sample_household).allowed_community_changes.to_a).to(
        contain_exactly(community, communityB)
      )
    end

    it "returns all communities for super admins" do
      # This query crosses a tenant boundary so need to do it unscoped.
      ActsAsTenant.unscoped do
        expect(HouseholdPolicy.new(super_admin, sample_household).allowed_community_changes.to_a).to(
          contain_exactly(community, communityB, communityX)
        )
      end
    end
  end

  describe "ensure_allowed_community_id" do
    include_context "policy permissions"
    let(:params) { {community_id: target_id} }
    let(:policy) { described_class.new(user, Household.new(community: community)) }

    before do
      allow(policy).to receive(:allowed_community_changes).and_return([double(id: 1), double(id: 2)])
      policy.ensure_allowed_community_id(params)
    end

    context "when attempting to set permitted community_id" do
      let(:target_id) { 1 }
      it "should leave community_id param alone" do
        expect(params[:community_id]).to eq(1)
      end
    end

    context "when attempting to set unpermitted community_id" do
      let(:target_id) { 3 }
      it "should nullify community_id param" do
        expect(params[:community_id]).to be_nil
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Household }

    # We need to list all the users that will be used in the spec here, otherwise they will get
    # created too late and their households will show up in `permitted` but not in our expectation.
    let!(:objs_in_community) { [user, other_user, inactive_user, admin, cluster_admin].map(&:household) }
    let!(:objs_in_cluster) { [userB.household] }
    let!(:inactive_household) { inactive_user.household }

    context "normal" do
      context "for regular users" do
        let(:actor) { user }
        it "returns all households except inactive ones" do
          is_expected.to match_array(objs_in_community + objs_in_cluster - [inactive_household])
        end
      end

      context "for inactive user" do
        let(:actor) { inactive_user }
        it { is_expected.to be_empty }
      end
    end

    describe "administerable" do
      let(:method) { :administerable }
      it_behaves_like "permits only admins in community"
    end
  end

  describe "permitted attributes" do
    let(:basic_attribs) do
      [:name, :garage_nums, :keyholders,
       {vehicles_attributes: %i[id make model color plate _destroy]},
       {emergency_contacts_attributes: %i[id name relationship main_phone alt_phone
                                          email location country_code _destroy]},
       {pets_attributes: %i[id name species color vet caregivers health_issues _destroy]}]
    end
    let(:admin_attribs) { basic_attribs.concat(%i[unit_num_and_suffix old_id old_name member_type_id]) }
    let(:cluster_admin_attribs) { admin_attribs << :community_id }
    let(:user) { create(:user) }
    let(:admin) { create(:admin) }
    let(:cluster_admin) { create(:cluster_admin) }
    let(:household) { create(:household) }

    subject { HouseholdPolicy.new(user, household).permitted_attributes }

    context "regular user" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(*basic_attribs)
      end
    end

    context "admin" do
      let(:user) { admin }

      it "should allow admin and basic attribs" do
        expect(subject).to contain_exactly(*admin_attribs)
      end
    end

    context "cluster admin" do
      let(:user) { cluster_admin }

      it "should allow all attribs" do
        expect(subject).to contain_exactly(*cluster_admin_attribs)
      end
    end
  end
end
