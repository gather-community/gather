# frozen_string_literal: true

require "rails_helper"

describe Work::MealJobSyncSettingCollection do
  let!(:role1) { create(:meal_role, :head_cook) }
  let!(:role2) { create(:meal_role, title: "Delta") }
  let!(:role3) { create(:meal_role, title: "Charlie") }
  let!(:role4) { create(:meal_role, title: "Bravo") }
  let!(:role5) { create(:meal_role, title: "Alpha") }
  let!(:role6) { create(:meal_role, :inactive, title: "Echo") }
  let!(:formula1) { create(:meal_formula, name: "Zulu", roles: [role1, role2, role3, role4]) }
  let!(:formula2) { create(:meal_formula, name: "Yankee", roles: [role1, role5, role6]) }
  let!(:formula3) { create(:meal_formula, :inactive, name: "X-ray", roles: [role1, role2, role6]) }
  let!(:formula4) { create(:meal_formula, :inactive, name: "Victor", roles: [role1]) }
  let!(:formula5) { create(:meal_formula, name: "Zzz", roles: [role1]) }
  subject(:result) { described_class.new(period: period).settings_by_formula }

  context "with new period" do
    let!(:period) do
      build(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                          meal_job_sync_settings_attributes: {
                            "0" => {formula_id: formula1.id, role_id: role1.id}
                          })
    end

    it "is correct" do
      expect(result.size).to eq(3)
      expect(result.keys).to eq([formula2, formula1, formula5])

      expect(result[formula1].size).to eq(4)

      expect(result[formula1][0].formula).to eq(formula1)
      expect(result[formula1][0].role).to eq(role1)
      expect(result[formula1][0].selected?).to be(true)
      expect(result[formula1][0].legacy?).to be(false)

      expect(result[formula1][1].formula).to eq(formula1)
      expect(result[formula1][1].role).to eq(role4)
      expect(result[formula1][1].selected?).to be(false)
      expect(result[formula1][1].legacy?).to be(false)

      expect(result[formula1][2].formula).to eq(formula1)
      expect(result[formula1][2].role).to eq(role3)
      expect(result[formula1][2].selected?).to be(false)
      expect(result[formula1][2].legacy?).to be(false)

      expect(result[formula1][3].formula).to eq(formula1)
      expect(result[formula1][3].role).to eq(role2)
      expect(result[formula1][3].selected?).to be(false)
      expect(result[formula1][3].legacy?).to be(false)

      expect(result[formula2].size).to eq(2)

      expect(result[formula2][0].formula).to eq(formula2)
      expect(result[formula2][0].role).to eq(role1)
      expect(result[formula2][0].selected?).to be(false)
      expect(result[formula2][0].legacy?).to be(false)

      expect(result[formula2][1].formula).to eq(formula2)
      expect(result[formula2][1].role).to eq(role5)
      expect(result[formula2][1].selected?).to be(false)
      expect(result[formula2][1].legacy?).to be(false)

      expect(result[formula5].size).to eq(1)

      expect(result[formula5][0].formula).to eq(formula5)
      expect(result[formula5][0].role).to eq(role1)
      expect(result[formula5][0].selected?).to be(false)
      expect(result[formula5][0].legacy?).to be(false)
    end
  end

  context "with existing period" do
    let!(:period) do
      create(:work_period, starts_on: "2020-01-01", ends_on: "2020-01-31", meal_job_sync: true,
                           meal_job_sync_settings_attributes: {
                             "0" => {formula_id: formula1.id, role_id: role1.id},
                             "1" => {formula_id: formula1.id, role_id: role3.id},
                             "2" => {formula_id: formula2.id, role_id: role1.id},
                             "3" => {formula_id: formula2.id, role_id: role5.id},
                             "4" => {formula_id: formula3.id, role_id: role1.id},
                             "5" => {formula_id: formula3.id, role_id: role6.id}
                           })
    end
    subject(:result) { described_class.new(period: period).settings_by_formula }

    before do
      formula1.roles.delete(role3)
    end

    it "is correct" do
      expect(result.size).to eq(4)
      expect(result.keys).to eq([formula2, formula1, formula5, formula3]) # Inactive last

      expect(result[formula1].size).to eq(4)

      expect(result[formula1][0].formula).to eq(formula1)
      expect(result[formula1][0].role).to eq(role1)
      expect(result[formula1][0].selected?).to be(true)
      expect(result[formula1][0].legacy?).to be(false)

      expect(result[formula1][1].formula).to eq(formula1)
      expect(result[formula1][1].role).to eq(role4)
      expect(result[formula1][1].selected?).to be(false)
      expect(result[formula1][1].legacy?).to be(false)

      expect(result[formula1][2].formula).to eq(formula1)
      expect(result[formula1][2].role).to eq(role2)
      expect(result[formula1][2].selected?).to be(false)
      expect(result[formula1][2].legacy?).to be(false)

      expect(result[formula1][3].formula).to eq(formula1)
      expect(result[formula1][3].role).to eq(role3)
      expect(result[formula1][3].selected?).to be(true)
      expect(result[formula1][3].legacy?).to be(true)

      expect(result[formula2].size).to eq(2)

      expect(result[formula2][0].formula).to eq(formula2)
      expect(result[formula2][0].role).to eq(role1)
      expect(result[formula2][0].selected?).to be(true)
      expect(result[formula2][0].legacy?).to be(false)

      expect(result[formula2][1].formula).to eq(formula2)
      expect(result[formula2][1].role).to eq(role5)
      expect(result[formula2][1].selected?).to be(true)
      expect(result[formula2][1].legacy?).to be(false)

      # This is an inactive formula but it's here because there are existing settings for it.
      expect(result[formula3].size).to eq(3)

      expect(result[formula3][0].formula).to eq(formula3)
      expect(result[formula3][0].role).to eq(role1)
      expect(result[formula3][0].selected?).to be(true)
      expect(result[formula3][0].legacy?).to be(true)

      expect(result[formula3][1].formula).to eq(formula3)
      expect(result[formula3][1].role).to eq(role2)
      expect(result[formula3][1].selected?).to be(false)
      expect(result[formula3][1].legacy?).to be(true) # Still legacy b/c formula is inactive

      expect(result[formula3][2].formula).to eq(formula3)
      expect(result[formula3][2].role).to eq(role6)
      expect(result[formula3][2].selected?).to be(true)
      expect(result[formula3][2].legacy?).to be(true) # Legacy b/c both formula AND role are inative

      # formula5 isn't involved in any persisted settings but should still show up in the collection
      # in case someone wants to add it in later.
      expect(result[formula5].size).to eq(1)

      expect(result[formula5][0].formula).to eq(formula5)
      expect(result[formula5][0].role).to eq(role1)
      expect(result[formula5][0].selected?).to be(false)
      expect(result[formula5][0].legacy?).to be(false)
    end
  end
end
