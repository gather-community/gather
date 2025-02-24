# frozen_string_literal: true

require "rails_helper"

describe Work::MealJobSynchronizer do
  let!(:meals_ctte) { create(:group) }

  context "on period create" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) do
      create(:meal_role, title: "A", count_per_meal: 3, time_type: "date_time",
                         shift_start: -30, shift_end: 30,
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
        expect(role1_job.shifts[0].assignments.count).to eq(1)
        expect(role1_job.shifts[0].assignments[0].user).to eq(meal2.head_cook)
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
        "1" => {id: # Should kill shifts
settings.detect do |s|
  s.role_id == role2.id
end.id, _destroy: "1"},
        "2" => {id: # Should kill job
settings.detect do |s|
  s.role_id == role3.id
end.id, _destroy: "1"},
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

  context "on period update when role name has changed to match existing job" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) { create(:meal_role) }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2]) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end
    let!(:dupe_job) { create(:work_job, period: period, title: "Head Cooke") } # Initially not a collision.

    it "handles duplicate name" do
      role1.update(work_job_title: "Head Cooke") # This doesn't cause sync immediately.

      # This update causes a sync which generates collision.
      settings = period.meal_job_sync_settings
      period.update!(meal_job_sync_settings_attributes: {
        "0" => {id: settings.detect { |s| s.role_id == role1.id }.id}, # No change
        "1" => {formula_id: formula1.id, role_id: role2.id} # Newly added
      })

      expect(Work::Job.find_by(meal_role: role1).title).to eq("Head Cooke 2")
    end
  end

  context "on period update only a sync setting is deleted" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) { create(:meal_role) }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2]) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id},
                             "1" => {formula_id: formula1.id, role_id: role2.id}
                           })
    end

    it "causes sync" do
      expect(Work::MealJobSynchronizer.instance).to receive(:sync_jobs_and_shifts)
      period.reload
      settings = period.meal_job_sync_settings
      period.update!(meal_job_sync_settings_attributes: {
        "0" => {id: settings.detect { |s| s.role_id == role1.id }.id},
        "1" => {id: settings.detect { |s| s.role_id == role2.id }.id, _destroy: "1"}
      })
    end
  end

  context "on period update when dates or sync settings don't change" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:formula1) { create(:meal_formula, roles: [role1]) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end

    it "doesn't cause sync" do
      expect(Work::MealJobSynchronizer.instance).not_to receive(:sync_jobs_and_shifts)
      period.reload
      settings = period.meal_job_sync_settings
      period.update!(meal_job_sync_settings_attributes: {"0" => {id: settings.first.id}})
    end
  end

  context "on period update when meal job sync disabled" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:formula1) { create(:meal_formula, roles: [role1]) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end

    it "deletes all jobs" do
      period.update!(meal_job_sync: false)
      expect(Work::Job.count).to be_zero
    end
  end

  context "on role update" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:formula1) { create(:meal_formula, roles: [role1]) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           phase: phase, meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end

    context "when period in draft phase" do
      let(:phase) { "draft" }
      it "causes sync" do
        role1.update!(work_job_title: "Head Cooke")
        expect(Work::Job.first.title).to eq("Head Cooke")
      end
    end

    context "when period in other phase" do
      let(:phase) { "ready" }
      it "doesn't cause sync" do
        role1.update!(work_job_title: "Head Cooke")
        expect(Work::Job.first.title).to eq("Head Cook")
      end
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

  context "on served_at change within period" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:formula1) { create(:meal_formula, roles: [role1]) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end

    it "updates shift time" do
      meal1.update!(served_at: "2020-01-02 18:00")
      expect(Work::Shift.count).to eq(1)
      expect(Work::Shift.first.starts_at).to eq(Time.zone.parse("2020-01-02 00:00"))
    end
  end

  context "on served_at change to different period" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:formula1) { create(:meal_formula, roles: [role1]) }
    let!(:period1) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end
    let!(:period2) do
      create(:work_period, starts_on: "2020-02-01", ends_on: "2020-02-29", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id}
                           })
    end

    it "destroys old job and creates new one in correct period" do
      meal1.update!(served_at: "2020-02-01 18:00")
      expect(Work::Job.count).to eq(1)
      expect(Work::Shift.count).to eq(1)

      expect(Work::Job.first.period).to eq(period2)
      expect(Work::Shift.first.starts_at).to eq(Time.zone.parse("2020-02-01 00:00"))
    end
  end

  context "on meal formula change to formula with different roles" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) { create(:meal_role) }
    let!(:role3) { create(:meal_role) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2]) }
    let!(:formula2) { create(:meal_formula, roles: [role1, role3]) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role2.id},
                             "1" => {formula_id: formula2.id, role_id: role3.id}
                           })
    end

    it "destroys old shift and creates new one" do
      meal1.update!(formula: formula2)
      expect(Work::Job.count).to eq(1)
      expect(Work::Shift.count).to eq(1)

      expect(Work::Job.first.meal_role).to eq(role3)
      expect(Work::Shift.first.starts_at).to eq(Time.zone.parse("2020-01-01 00:00"))
    end
  end

  context "on meal destroy" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) { create(:meal_role) }
    let!(:meal1) { create(:meal, served_at: "2020-01-01 18:00", formula: formula1) }
    let!(:meal2) { create(:meal, served_at: "2020-01-02 18:00", formula: formula2) }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2]) }
    let!(:formula2) { create(:meal_formula, roles: [role1]) }
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id},
                             "1" => {formula_id: formula1.id, role_id: role2.id},
                             "2" => {formula_id: formula2.id, role_id: role1.id}
                           })
    end

    it "destroys one job and one shift" do
      expect(Work::Job.count).to eq(2)
      expect(Work::Shift.count).to eq(3)
      meal1.destroy
      expect(Work::Job.count).to eq(1)
      expect(Work::Shift.count).to eq(1)
      expect(Work::Job.first.meal_role).to eq(role1)
      expect(Work::Shift.first.meal).to eq(meal2)
    end
  end
end
