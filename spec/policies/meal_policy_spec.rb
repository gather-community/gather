require 'rails_helper'

describe MealPolicy do
  include_context "policy objs"

  let(:meal) { Meal.new(community: community, communities: [community]) }
  let(:record) { meal }

  describe "permissions" do
    permissions :index?, :reports? do
      it_behaves_like "grants access to users in cluster"
    end

    permissions :show?, :summary? do
      it "grants access to users from invited communities" do
        expect(subject).to permit(user, meal)
      end

      it "denies access to users from uninvited communities in the cluster" do
        expect(subject).not_to permit(user_in_cluster, meal)
      end

      it "grants access to non-invited workers" do
        meal.assignments.build(user: user_in_cluster)
        expect(subject).to permit(user_in_cluster, meal)
      end

      it "grants access to non-invited but signed-up folks" do
        meal.signups.build(household: user_in_cluster.household)
        expect(subject).to permit(user_in_cluster, meal)
      end
    end

    permissions :new?, :create?, :administer?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", "meals_coordinator"
    end

    permissions :edit?, :update? do
      # We let anyone do this so they can change assignments.
      it_behaves_like "grants access to users in community"

      it "grants access to workers not in host community" do
        meal.assignments.build(user: user_in_cluster)
        expect(subject).to permit(user_in_cluster, meal)
      end
    end

    permissions :set_menu?, :close?, :reopen? do
      it_behaves_like "permits admins or special role but not regular users", "meals_coordinator"

      it "grants access to head cook" do
        meal.head_cook = user
        expect(subject).to permit(user, meal)
      end
    end

    permissions :reopen? do
      it "denies access to head cook if meal in past" do
        meal.served_at = Time.current - 7.days
        meal.head_cook = user
        expect(subject).not_to permit(user, meal)
      end
    end

    permissions :finalize? do
      it_behaves_like "permits admins or special role but not regular users", "biller"
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
      meal3.signups.create!(household: user.household, adult_meat: 2)
    end

    it "returns meals invited to, assigned to, or signed up for" do
      expect(permitted).to contain_exactly(meal1, meal2, meal3)
    end

    context "with inactive user" do
      before { user.deactivated_at = Time.current }

      it "returns meals only signed up for" do
        expect(permitted).to contain_exactly(meal3)
      end
    end
  end

  describe "permitted_attributes" do
    subject { MealPolicy.new(user, meal).permitted_attributes }
    let(:assign_attribs) {[{
      :head_cook_assign_attributes => [:id, :user_id],
      :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
      :table_setter_assigns_attributes => [:id, :user_id, :_destroy],
      :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
    }]}
    let(:head_cook_attribs) { [:allergen_dairy, :title, :capacity, :entrees] }

    context "regular user" do
      it "should allow only assignment attribs" do
        expect(subject).to contain_exactly(*assign_attribs)
      end
    end

    context "head cook" do
      before { meal.head_cook = user }

      it "should allow more stuff" do
        expect(subject).to include(*(assign_attribs + head_cook_attribs))
        expect(subject).not_to include(:discount, :community_id)
      end
    end

    context "admin" do
      let(:user) { admin }

      it "should allow even more stuff" do
        expect(subject).to include(*(assign_attribs + head_cook_attribs + [:discount]))
        expect(subject).not_to include(:community_id)
      end
    end

    context "outside admin" do
      let(:user) { admin_in_cluster }

      it "should have only basic attribs" do
        expect(subject).to contain_exactly(*assign_attribs)
      end
    end
  end
end
