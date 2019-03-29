# frozen_string_literal: true

require "rails_helper"

describe MealPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:head_cook) { create(:user) }
    let(:meal) { create(:meal, communities: [community, communityC], head_cook: head_cook) }
    let(:record) { meal }

    permissions :index?, :report? do
      it_behaves_like "permits cluster and super admins"
      it_behaves_like "permits users in cluster"
    end

    permissions :show?, :summary? do
      it_behaves_like "permits cluster and super admins"
      it_behaves_like "permits users in community only"

      it "permits users in other invited communities" do
        expect(subject).to permit(user_cmtyC, meal)
      end

      it "permits non-invited workers" do
        meal.assignments << create(:meal_assignment, meal: meal, user: user_cmtyB)
        expect(subject).to permit(user_cmtyB, meal)
      end

      it "permits non-invited but signed-up folks" do
        meal.signups.create(household: user_cmtyB.household)
        expect(subject).to permit(user_cmtyB, meal)
      end
    end

    permissions :new?, :create?, :destroy?, :change_date_loc_invites?, :change_formula?,
      :change_workers_without_notification? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end

    permissions :edit?, :update?, :change_workers? do
      # We let anyone in host community do this so they can change assignments.
      it_behaves_like "permits admins from community"
      it_behaves_like "permits users in community only"

      it "permits non-invited workers" do
        meal.assignments << create(:meal_assignment, meal: meal, user: user_cmtyB)
        expect(subject).to permit(user_cmtyB, meal)
      end
    end

    permissions :change_formula?, :change_signups?, :change_expenses? do
      it_behaves_like "permits admins or special role but not regular users", :biller

      it "forbids if finalized" do
        stub_status("finalized")
        expect(subject).not_to permit(admin, meal)
      end
    end

    permissions :change_menu?, :change_signups?, :change_capacity?, :close?, :cancel? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator

      context "head cook" do
        let(:head_cook) { user }
        it { is_expected.to permit(user, meal) }
      end

      it "forbids if finalized" do
        stub_status("finalized")
        expect(subject).not_to permit(admin, meal)
      end
    end

    permissions :close?, :reopen? do
      it "forbids if meal cancelled" do
        stub_status("cancelled")
        expect(subject).not_to permit(admin, meal)
      end
    end

    permissions :reopen? do
      before { meal.close! }

      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator

      it "permits if day prior to meal" do
        Timecop.travel(meal.served_at - 1.day) do
          expect(subject).to permit(admin, meal)
        end
      end

      it "permits if after meal but same day" do
        Timecop.travel(meal.served_at + 1.minute) do
          expect(subject).to permit(admin, meal)
        end
      end

      it "forbids if meal open" do
        meal.reopen!
        expect(subject).not_to permit(admin, meal)
      end

      it "forbids if day after meal" do
        Timecop.travel(meal.served_at + 1.day) do
          expect(subject).not_to permit(admin, meal)
        end
      end
    end

    permissions :finalize? do
      before do
        stub_status("closed")
        meal.served_at = Time.current - 30.minutes
      end

      it_behaves_like "permits admins or special role but not regular users", :biller

      it "forbids if meal in future" do
        meal.served_at = Time.current + 2.days
        expect(subject).not_to permit(admin, meal)
      end

      it "forbids if wrong status" do
        %w[cancelled finalized open].each do |bad_status|
          stub_status(bad_status)
          expect(subject).not_to permit(admin, meal)
        end
      end

      describe "cooks_can_finalize setting" do
        let(:head_cook) { user }

        before do
          community.settings.meals.cooks_can_finalize = value
        end

        context "true" do
          let(:value) { true }
          it { is_expected.to permit(user, meal) }
        end

        context "false" do
          let(:value) { false }
          it { is_expected.not_to permit(user, meal) }
        end
      end
    end

    permissions :cancel? do
      it "forbids if meal already cancelled" do
        stub_status("cancelled")
        expect(subject).not_to permit(admin, meal)
      end

      it "forbids if meal finalized" do
        stub_status("finalized")
        expect(subject).not_to permit(admin, meal)
      end
    end

    permissions :send_message? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator

      it "permits team members" do
        meal.assignments << create(:meal_assignment, meal: meal, user: user)
        expect(subject).to permit(user, meal)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Meal }
    let!(:meal1) { create(:meal, communities: [user.community]) } # Invited
    let!(:meal2) { create(:meal, cleaners: [actor], communities: [communityB]) } # Assigned
    let!(:meal3) { create(:meal, communities: [communityB]) } # Signed up
    let!(:meal4) { create(:meal, communities: [communityB]) } # None of the above

    before do
      meal3.signups.create!(household: actor.household, adult_meat: 2)
    end

    context "as regular user" do
      let(:actor) { user }

      it "returns meals invited to, assigned to, or signed up for" do
        is_expected.to contain_exactly(meal1, meal2, meal3)
      end
    end

    context "as admin" do
      let(:actor) { admin }

      it "returns meals invited to, assigned to, or signed up for" do
        is_expected.to contain_exactly(meal1, meal2, meal3)
      end
    end

    context "as cluster admin" do
      let(:actor) { cluster_admin }

      it "returns all meals" do
        is_expected.to contain_exactly(meal1, meal2, meal3, meal4)
      end
    end

    context "as inactive user" do
      let(:actor) { inactive_user }

      it "returns meals only signed up for" do
        is_expected.to contain_exactly(meal3)
      end
    end
  end

  describe "permitted_attributes" do
    include_context "policy permissions"
    subject { MealPolicy.new(actor, meal).permitted_attributes }
    let(:head_cook) { create(:user) }
    let(:meal) { create(:meal, head_cook: head_cook, communities: [community, communityC]) }
    let(:date_loc_invite_attribs) do
      [:served_at, {resource_ids: []}, {community_boxes: [Community.all.pluck(:id).map(&:to_s)]}]
    end
    let(:menu_attribs) do
      %i[title entrees side kids dessert notes no_allergens] + Meal::ALLERGENS.map { |a| :"allergen_#{a}" }
    end
    let(:worker_attribs) { [assignments_attributes: %i[id user_id role_id _destroy]] }
    let(:head_cook_attribs) { %i[allergen_dairy title capacity entrees] }
    let(:admin_attribs) { [:formula_id] }
    let(:signup_attribs) do
      [signups_attributes: [:id, :household_id, lines_attributes: %i[id quantity item_id]]]
    end
    let(:expense_attribs) { [cost_attributes: %i[ingredient_cost pantry_cost payment_method]] }

    shared_examples_for "admin or meals coordinator" do
      it "should allow even more stuff" do
        expect(subject).to match_array(date_loc_invite_attribs + menu_attribs + worker_attribs +
          signup_attribs + expense_attribs + %i[capacity formula_id])
      end

      it "should not allow formula_id, capacity if meal finalized" do
        stub_status("finalized")
        expect(subject).not_to include(:formula_id)
        expect(subject).not_to include(:capacity)
      end
    end

    context "regular user" do
      let(:actor) { user }

      it "should allow only assignment attribs" do
        expect(subject).to match_array(worker_attribs)
      end
    end

    context "head cook" do
      let(:actor) { user }
      let(:head_cook) { user }

      it "should allow more stuff" do
        expect(subject).to match_array(menu_attribs + worker_attribs +
          signup_attribs + expense_attribs + [:capacity])
      end
    end

    context "biller" do
      let(:actor) { biller }

      it "should allow edit formula" do
        expect(subject).to match_array((worker_attribs + signup_attribs + expense_attribs) << :formula_id)
      end
    end

    context "admin" do
      let(:actor) { admin }

      it_behaves_like "admin or meals coordinator"
    end

    context "meals coordinator" do
      let(:actor) { meals_coordinator }

      it_behaves_like "admin or meals coordinator"
    end

    context "outside admin" do
      let(:actor) { admin_cmtyB }

      it "should have nothing" do
        expect(subject).to be_empty
      end
    end
  end

  def stub_status(value)
    allow(meal).to receive(:status).and_return(value)
  end
end
