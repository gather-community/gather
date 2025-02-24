# frozen_string_literal: true

require "rails_helper"

describe Work::MealAssignmentSynchronizer do
  let!(:role1) { create(:meal_role, :head_cook) }
  let!(:role2) { create(:meal_role, title: "A", count_per_meal: 3) }
  let(:formula) { create(:meal_formula, roles: [role1, role2]) }
  let!(:meal) { create(:meal, formula: formula, head_cook: false) }
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:user3) { create(:user) }
  let!(:user4) { create(:user) }
  let!(:assignment1) { create(:meal_assignment, meal: meal, role: role1, user: user1) }
  let!(:assignment2) { create(:meal_assignment, meal: meal, role: role2, user: user2) }
  let!(:assignment3) { create(:meal_assignment, meal: meal, role: role2, user: user3) }

  context "without existing job" do
    context "on job create" do
      it "copies assignments from meals" do
        job1 = create(:work_job, meal_role: role1, shift_count: 1, meals: [meal])
        job2 = create(:work_job, meal_role: role2, shift_count: 1, meals: [meal])
        shift = job1.shifts[0]
        expect(shift.assignments.map(&:user_id)).to contain_exactly(user1.id)
        shift = job2.shifts[0]
        expect(shift.assignments.map(&:user_id)).to contain_exactly(user2.id, user3.id)

        # Ensure meal assignments haven't changed unexpectedly
        expect(meal_assignments_for_role(role1)).to contain_exactly(user1.id)
        expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user3.id)
      end
    end
  end

  context "with existing job" do
    let(:double_signups_allowed) { false }
    let!(:job) do
      # Create and then load fresh so that syncing flags are not set.
      job = create(:work_job, meal_role: role2, shift_count: 1, meals: [meal],
                              double_signups_allowed: double_signups_allowed)
      Work::Job.find(job.id)
    end

    context "on work job signup" do
      it "copies new assignment to meals" do
        job.shifts[0].assignments.create!(user: user4)
        expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user3.id, user4.id)

        # Ensure work assignments haven't changed unexpectedly
        expect(job_assignments).to contain_exactly(user2.id, user3.id, user4.id)
      end

      context "when double signups are allowed" do
        let(:double_signups_allowed) { true }

        it "copies both signups" do
          job.shifts[0].assignments.create!(user: user4)
          a2 = job.shifts[0].assignments.create!(user: user4)
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user3.id, user4.id, user4.id)

          # Ensure work assignments haven't changed unexpectedly
          expect(job_assignments).to contain_exactly(user2.id, user3.id, user4.id, user4.id)

          a2.reload.destroy
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user3.id, user4.id)

          # Ensure work assignments haven't changed unexpectedly
          expect(job_assignments).to contain_exactly(user2.id, user3.id, user4.id)
        end
      end
    end

    context "on work job unsignup" do
      it "removes assignment from meals" do
        job.shifts[0].assignments.find_by(user: user3).destroy
        expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id)

        # Ensure work assignments haven't changed unexpectedly
        expect(job_assignments).to contain_exactly(user2.id)
      end
    end

    context "on work job assignment change" do
      context "with matching meal assignment" do
        it "updates existing meal assignment" do
          job.shifts[0].assignments.find_by(user: user3).update!(user_id: user4.id)
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user4.id)

          # Ensure work assignments haven't changed unexpectedly
          expect(job_assignments).to contain_exactly(user2.id, user4.id)
        end
      end

      context "without matching meal assignment" do
        before do
          assign = meal.assignments.find_by(role: role2, user_id: user3.id)
          assign.syncing = true # Prevent sync on destroy
          assign.destroy
        end

        it "creates new meal assignment" do
          job.shifts[0].assignments.find_by(user: user3).update!(user_id: user4.id)
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user4.id)

          # Ensure work assignments haven't changed unexpectedly
          expect(job_assignments).to contain_exactly(user2.id, user4.id)
        end
      end
    end

    context "on work job destroy" do
      it "does not disturb meal assigns" do
        job.destroy
        expect(meal.assignments.count).to eq(3)
      end
    end

    context "on meal job signup" do
      it "copies new assignment to work" do
        meal.assignments.create!(user: user4, role: role2)
        expect(job_assignments).to contain_exactly(user2.id, user3.id, user4.id)
      end

      context "when work assignment already exists for some reason" do
        let!(:work_assign) { job.shifts[0].assignments.create!(user: user4, syncing: true) }

        it "should not create another one" do
          # First make sure that the creation of the work_assign above didn't cause a sync.
          expect(meal.assignments.map(&:user)).not_to include(user4)

          meal.assignments.create!(user: user4, role: role2)
          expect(job_assignments).to contain_exactly(user2.id, user3.id, user4.id)

          # Ensure meal assignments haven't changed unexpectedly
          expect(meal_assignments_for_role(role1)).to contain_exactly(user1.id)
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user3.id, user4.id)
        end
      end
    end

    context "on meal assignment change" do
      context "with matching work assignment" do
        it "updates existing work assignment" do
          meal.assignments.find_by(user: user3).update!(user_id: user4.id)
          expect(job_assignments).to contain_exactly(user2.id, user4.id)

          # Ensure meal assignments haven't changed unexpectedly
          expect(meal_assignments_for_role(role1)).to contain_exactly(user1.id)
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user4.id)
        end
      end

      context "without matching work assignment" do
        before do
          assign = job.shifts[0].assignments.find_by(user: user3)
          assign.syncing = true # Prevent sync on destroy
          assign.destroy
        end

        it "creates new work assignment" do
          meal.assignments.find_by(user: user3).update!(user_id: user4.id)
          expect(job_assignments).to contain_exactly(user2.id, user4.id)

          # Ensure meal assignments haven't changed unexpectedly
          expect(meal_assignments_for_role(role1)).to contain_exactly(user1.id)
          expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id, user4.id)
        end
      end
    end

    context "on meal job unsignup" do
      it "removes assignment from work" do
        meal.assignments.find_by(user: user3, role: role2).destroy
        expect(job_assignments).to contain_exactly(user2.id)

        # Ensure meal assignments haven't changed unexpectedly
        expect(meal_assignments_for_role(role1)).to contain_exactly(user1.id)
        expect(meal_assignments_for_role(role2)).to contain_exactly(user2.id)
      end
    end

    context "on meal job signup plus separate unsignup" do
      it "syncs to work" do
        meal.update!(assignments_attributes: {
          "1" => {"id" => assignment2.id, "_destroy" => "1"},
          "2" => {"user_id" => user4.id, "role_id" => role2.id}
        })
        expect(job_assignments).to contain_exactly(user3.id, user4.id)

        # Ensure meal assignments haven't changed unexpectedly
        expect(meal_assignments_for_role(role1)).to contain_exactly(user1.id)
        expect(meal_assignments_for_role(role2)).to contain_exactly(user3.id, user4.id)
      end
    end

    context "on meal destroy" do
      it "destroys work shift and assignments" do
        meal.destroy
        expect(job.shifts.count).to eq(0)
      end
    end
  end

  def meal_assignments_for_role(role)
    meal.assignments.where(role_id: role.id).map(&:user_id)
  end

  def job_assignments
    job.shifts[0].assignments.reload.map(&:user_id)
  end
end
