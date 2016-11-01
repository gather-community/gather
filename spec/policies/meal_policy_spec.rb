require 'rails_helper'

describe MealPolicy do

  describe "permissions" do
    include_context "policy objs"

    permissions :index?, :report? do
      it "grants access to everyone" do
        expect(subject).to permit(user, Meal)
      end
    end

    permissions :show?, :summary? do
      it "grants access to invitees" do
        expect(subject).to permit(user, Meal.new(communities: [community]))
      end

      it "grants access to assignees even if not invited" do
        expect(subject).to permit(outside_admin, Meal.new(assignments: [Assignment.new(user: outside_admin)]))
      end

      it "grants access to those signed up even if not invited" do
        expect(subject).to permit(outside_admin, Meal.new(signups: [Signup.new(household: outside_admin.household)]))
      end

      it "denies access to plain others" do
        expect(subject).not_to permit(user, Meal.new)
      end
    end

    permissions :new?, :create? do
      it "grants access to admins" do
        expect(subject).to permit(admin, Meal)
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(user, Meal)
      end
    end

    permissions :edit?, :update? do
      it "grants access to anyone in host community" do
        expect(subject).to permit(user, Meal.new(host_community: community))
      end

      it "grants access to assignees even if not in host community" do
        expect(subject).to permit(outside_admin, Meal.new(assignments: [Assignment.new(user: outside_admin)]))
      end

      it "denies access to those in other communities" do
        expect(subject).not_to permit(outside_admin, Meal.new(host_community: community))
      end
    end

    permissions :administer?, :destroy? do
      it "grants access to admins in community" do
        expect(subject).to permit(admin, Meal.new(host_community: community))
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(user, Meal.new(host_community: community))
      end

      it "denies access to admins in other communities" do
        expect(subject).not_to permit(outside_admin, Meal.new(host_community: community))
      end
    end

    permissions :set_menu?, :close?, :reopen?, :summary? do
      it "grants access to admins in community" do
        expect(subject).to permit(admin, Meal.new(host_community: community, communities: [community]))
      end

      it "grants access to head cook" do
        user = create(:user)
        meal = create(:meal, head_cook: user, communities: [create(:community)])
        expect(subject).to permit(user, meal)
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(user, Meal.new(host_community: community))
      end

      it "denies access to admins in other communities" do
        expect(subject).not_to permit(outside_admin, Meal.new(host_community: community))
      end
    end

    permissions :reopen? do
      it "denies access to head cook if meal in past" do
        user = create(:user)
        meal = create(:meal, served_at: Time.now - 7.days, head_cook: user, communities: [create(:community)])
        expect(subject).not_to permit(user, meal)
      end
    end

    permissions :finalize? do
      it "grants access to admins in community" do
        expect(subject).to permit(admin, Meal.new(host_community: community))
      end

      it "grants access to billers in community" do
        expect(subject).to permit(biller, Meal.new(host_community: community))
      end

      it "denies access to admins in other communities" do
        expect(subject).not_to permit(outside_admin, Meal.new(host_community: community))
      end

      it "denies access to billers in other communities" do
        expect(subject).not_to permit(outside_biller, Meal.new(host_community: community))
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(user, Meal.new)
      end
    end
  end

  describe "scope" do
    let!(:user) { create(:user) }
    let!(:other_community) { create(:community) }
    let!(:meal1) { create(:meal, communities: [user.community]) } # Invited
    let!(:meal2) { create(:meal, cleaners: [user], communities: [other_community]) } # Assigned
    let!(:meal3) { create(:meal, communities: [other_community]) } # Signed up
    let!(:meal4) { create(:meal, communities: [other_community]) } # None of the above
    let(:permitted) { MealPolicy::Scope.new(user, Meal.all).resolve }

    before do
      meal3.households << user.household
    end

    it "returns meals invited to, assigned to, or signed up for" do
      expect(permitted).to contain_exactly(meal1, meal2, meal3)
    end

    context "with inactive user" do
      before { user.deactivated_at = Time.now }

      it "returns meals only signed up for" do
        expect(permitted).to contain_exactly(meal3)
      end
    end
  end

  describe "permitted_attributes" do
    subject { MealPolicy.new(user, meal).permitted_attributes }
    let(:community) { Community.new }
    let(:user) { User.new(household: Household.new(community: community)) }
    let(:meal) { Meal.new(host_community: community) }
    let(:assign_attribs) {{
      :head_cook_assign_attributes => [:id, :user_id],
      :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
      :table_setter_assigns_attributes => [:id, :user_id, :_destroy],
      :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
    }}

    context "regular user" do
      it "should allow only assignment attribs" do
        expect(subject).to include(assign_attribs)
        expect(subject).not_to include(:allergen_dairy)
        expect(subject).not_to include(:title, :capacity, :entrees)
        expect(subject).not_to include(:discount, :host_community_id)
      end
    end

    context "head cook" do
      before { meal.head_cook = user }

      it "should allow more stuff" do
        expect(subject).to include(assign_attribs)
        expect(subject).to include(:allergen_dairy)
        expect(subject).to include(:title, :capacity, :entrees)
        expect(subject).not_to include(:discount, :host_community_id)
      end
    end

    context "hosting admin" do
      before { user.admin = true }

      it "should allow more stuff" do
        expect(subject).to include(assign_attribs)
        expect(subject).to include(:allergen_dairy)
        expect(subject).to include(:title, :capacity, :entrees)
        expect(subject).to include(:discount)
        expect(subject).not_to include(:host_community_id)
      end
    end
  end

end
