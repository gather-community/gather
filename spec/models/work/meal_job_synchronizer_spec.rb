# frozen_string_literal: true

require "rails_helper"

describe Work::MealJobSynchronizer do
  let!(:meals_ctte) { create(:group) }

  context "on period create" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) do
      create(:meal_role, title: "A", count_per_meal: 3, time_type: "date_time", shift_start: -30, shift_end: 30,
                         work_job_title: "Meal Crumbler", double_signups_allowed: true)
    end
    let!(:role3) { create(:meal_role, title: "B", count_per_meal: 2, shift_start: -120, shift_end: -30) }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2, role3]) }
    let!(:formula2) { create(:meal_formula, roles: [role1, role2]) }
    let!(:meal1) { create(:meal, served_at: "2020-12-31 18:00", formula: formula1) }
    let!(:meal2) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:meal3) { create(:meal, served_at: "2020-01-02 19:00", formula: formula1) }
    let!(:decoy_meal) { create(:meal, served_at: "2020-01-03 18:00", formula: formula2) }

    context "with no period sync setting" do
      it "doesn't sync" do
        create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: false)
        expect(Work::Job.count).to be_zero
      end
    end

    context "with period sync setting" do
      it "syncs appropriate roles" do
        # We don't import role3 in formula1, or formula2 at all.
        period = create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                                      meal_job_sync_settings_attributes: {
                                        "0" => {formula_id: formula1.id, role_id: role1.id},
                                        "1" => {formula_id: formula1.id, role_id: role2.id}
                                      },
                                      meal_job_requester: meals_ctte)
        expect(Work::Job.count).to eq(2)
        role1_job = Work::Job.find_by(meal_role: role1)
        expect(role1_job).to have_attributes(
          title: "Head Cook",
          description: role1.description,
          double_signups_allowed: false,
          hours: 1.5, # Default value
          meal_role_id: role1.id,
          period_id: period.id,
          requester_id: meals_ctte.id,
          slot_type: "fixed",
          time_type: "date_only"
        )
        expect(role1_job.shifts.count).to eq(2)
        expect(role1_job.shifts[0]).to have_attributes(
          starts_at: Time.zone.parse("2020-01-01 00:00"),
          ends_at: Time.zone.parse("2020-01-01 23:59"),
          meal_id: meal2.id,
          slots: 1
        )
        expect(role1_job.shifts[1]).to have_attributes(
          starts_at: Time.zone.parse("2020-01-02 00:00"),
          ends_at: Time.zone.parse("2020-01-02 23:59"),
          meal_id: meal3.id,
          slots: 1
        )

        role2_job = Work::Job.find_by(meal_role: role2)
        expect(role2_job).to have_attributes(
          title: "Meal Crumbler",
          description: role2.description,
          double_signups_allowed: true,
          hours: 1.0,
          meal_role_id: role2.id,
          period_id: period.id,
          requester_id: meals_ctte.id,
          slot_type: "fixed",
          time_type: "date_time"
        )
        expect(role2_job.shifts.count).to eq(2)
        expect(role2_job.shifts[0]).to have_attributes(
          starts_at: Time.zone.parse("2020-01-01 17:30"),
          ends_at: Time.zone.parse("2020-01-01 18:30"),
          meal_id: meal2.id,
          slots: 3
        )
        expect(role2_job.shifts[1]).to have_attributes(
          starts_at: Time.zone.parse("2020-01-02 18:30"),
          ends_at: Time.zone.parse("2020-01-02 19:30"),
          meal_id: meal3.id,
          slots: 3
        )
      end
    end
  end

  context "on period update" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) { create(:meal_role) }
    let!(:role3) { create(:meal_role) }
    let!(:role4) { create(:meal_role) }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2, role3, role4]) }
    let!(:formula2) { create(:meal_formula, roles: [role1, role2]) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:meal2) { create(:meal, served_at: "2020-01-02 18:00", formula: formula1) }
    let!(:meal3) { create(:meal, served_at: "2020-01-03 18:00", formula: formula2) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id},
                             "1" => {formula_id: formula1.id, role_id: role2.id},
                             "2" => {formula_id: formula1.id, role_id: role3.id},
                             "3" => {formula_id: formula2.id, role_id: role2.id}
                           })
    end
    let!(:decoy_job1) { create(:work_job, period: period, shift_count: 0) }
    let!(:decoy_job2) { create(:work_job, period: period, shift_count: 1) }

    it "creates and deletes jobs and shifts" do
      expect(Work::Job.all.map(&:meal_role_id)).to match_array([role1, role2, role3].map(&:id) << nil << nil)
      role1_job = Work::Job.find_by(meal_role: role1)
      expect(role1_job.shifts.map(&:meal_id)).to match_array([meal1, meal2].map(&:id))
      role2_job = Work::Job.find_by(meal_role: role2)
      expect(role2_job.shifts.map(&:meal_id)).to match_array([meal1, meal2, meal3].map(&:id))
      role3_job = Work::Job.find_by(meal_role: role3)
      expect(role3_job.shifts.map(&:meal_id)).to match_array([meal1, meal2].map(&:id))

      settings = period.meal_job_sync_settings
      period.update!(meal_job_sync_settings_attributes: {
        "0" => {id: settings.detect { |s| s.role_id == role1.id }.id}, # No change
        "1" => {id: settings.detect { |s| s.role_id == role2.id }.id, _destroy: "1"}, # Should kill shifts
        "2" => {id: settings.detect { |s| s.role_id == role3.id }.id, _destroy: "1"}, # Should kill job
        "3" => {formula_id: formula2.id, role_id: role1.id}, # Should add shifts
        "4" => {formula_id: formula1.id, role_id: role4.id} # Should add job
      })

      expect(Work::Job.all.map(&:meal_role_id)).to match_array([role1, role2, role4].map(&:id) << nil << nil)
      role1_job = Work::Job.find_by(meal_role: role1)
      expect(role1_job.shifts.map(&:meal_id)).to match_array([meal1, meal2, meal3].map(&:id))
      role2_job = Work::Job.find_by(meal_role: role2)
      expect(role2_job.shifts.map(&:meal_id)).to match_array([meal3].map(&:id))
      role4_job = Work::Job.find_by(meal_role: role4)
      expect(role4_job.shifts.map(&:meal_id)).to match_array([meal1, meal2].map(&:id))

      expect { decoy_job1.reload }.not_to raise_error
      expect { decoy_job2.reload }.not_to raise_error
      expect { decoy_job2.shifts[0].reload }.not_to raise_error
    end
  end

  context "on meal create" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:formula1) { create(:meal_formula, roles: [role1]) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end

    it "creates shift if meal is within period date range" do
      expect(Work::Job.count).to eq(1)
      expect(Work::Shift.count).to eq(1)

      meal2 = create(:meal, served_at: "2020-01-02 18:00", formula: formula1)
      expect(Work::Job.count).to eq(1)
      expect(Work::Job.first.shifts.map(&:meal_id)).to match_array([meal1, meal2].map(&:id))

      # This one is outside the range so no shift created.
      create(:meal, served_at: "2020-02-01 18:00", formula: formula1)
      expect(Work::Job.count).to eq(1)
      expect(Work::Job.first.shifts.map(&:meal_id)).to match_array([meal1, meal2].map(&:id))
    end
  end
end
