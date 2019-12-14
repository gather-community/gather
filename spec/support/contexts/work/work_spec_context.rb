# frozen_string_literal: true

shared_context "work" do
  shared_examples "handles no periods" do
    context "with no period" do
      let(:periods) { [] }

      context "as coordinator" do
        let(:actor) { create(:work_coordinator) }

        scenario "index" do
          visit(page_path)
          expect(page).to have_content("There are no active work periods. Please create one first.")
        end
      end

      context "as regular user" do
        let(:actor) { create(:user) }

        scenario "index" do
          visit(page_path)
          expect(page).to have_content("It looks like your community")
        end
      end
    end
  end

  shared_context "with jobs" do
    let!(:periods) do
      [
        create(:work_period, starts_on: Time.zone.today - 83.days, ends_on: Time.zone.today + 7.days,
                             phase: "open"),
        create(:work_period, starts_on: Time.zone.today + 8.days, ends_on: Time.zone.today + 87.days,
                             phase: "open")
      ]
    end
    let!(:users) do
      [
        actor,
        create(:user, first_name: "Jane", last_name: "Picard", household: actor.household),
        create(:user, first_name: "Churl", last_name: "Rox"),
        create(:user, :child, first_name: "Kid", last_name: "Knelt")
      ]
    end
    let!(:group) { create(:group, name: "Pants") }
    let!(:meal) { create(:meal, head_cook: false) }
    let!(:jobs) do
      [
        create(:work_job, period: periods[0], title: "Cook", shift_count: 1, shift_slots: 1,
                          meal_role: meal.formula.head_cook_role, meals: [meal]),
        create(:work_job, period: periods[0], title: "Fruct Coordinator", shift_count: 2, requester: group),
        create(:work_job, period: periods[0], title: "Whippersnapper", shift_count: 2),
        create(:work_job, period: periods[0], title: "Krusketarian", shift_count: 1, requester: group),
        create(:work_job, period: periods[1], title: "Plooge")
      ]
    end
  end

  shared_context "with assignments" do
    before do
      periods[0].update!(phase: "draft")
      jobs[0].shifts[0].assignments.create(user: users[1]) # preassigned
      periods[0].update!(phase: "open")
      jobs[1].shifts[1].assignments.create(user: actor)
      jobs[2].shifts[0].assignments.create(user: actor)
    end
  end

  def expect_jobs(*visible)
    visible.each { |j| expect(page).to have_content(j.title) }
    (jobs - visible).each { |j| expect(page).not_to have_content(j.title) }
  end
end
