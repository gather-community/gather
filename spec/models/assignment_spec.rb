require "rails_helper"

describe Assignment do
  describe "default timing" do
    let(:meal) { create(:meal, served_at: "2017-01-01 12:00") }

    context "for head_cook" do
      let(:assignment) { meal.head_cook_assign }

      it "should be reasonable" do
        expect(assignment.starts_at).to eq Time.zone.parse("2017-01-01 08:45")
        expect(assignment.ends_at).to eq Time.zone.parse("2017-01-01 12:00")
      end
    end

    context "for asst_cook" do
      let(:assignment) { meal.asst_cook_assigns.build }

      it "should be reasonable" do
        expect(assignment.starts_at).to eq Time.zone.parse("2017-01-01 09:45")
        expect(assignment.ends_at).to eq Time.zone.parse("2017-01-01 12:00")
      end
    end

    context "for table_setter" do
      let(:assignment) { meal.table_setter_assigns.build }

      it "should be reasonable" do
        expect(assignment.starts_at).to eq Time.zone.parse("2017-01-01 11:00")
        expect(assignment.ends_at).to eq Time.zone.parse("2017-01-01 12:00")
      end
    end

    context "for cleaner" do
      let(:assignment) { meal.cleaner_assigns.build }

      it "should be reasonable" do
        expect(assignment.starts_at).to eq Time.zone.parse("2017-01-01 12:45")
        expect(assignment.ends_at).to eq Time.zone.parse("2017-01-01 14:45")
      end
    end
  end

  describe "customized timing" do
    let(:meal) { create(:meal, served_at: "2017-01-01 12:00") }
    let(:assignment) { meal.asst_cook_assigns.build }

    before do
      meal.host_community.settings.meals.default_shift_times.start.asst_cook = -60
      meal.host_community.settings.meals.default_shift_times.end.asst_cook = 5
      meal.host_community.save!
    end

    it "should be correct" do
      expect(assignment.starts_at).to eq Time.zone.parse("2017-01-01 11:00")
      expect(assignment.ends_at).to eq Time.zone.parse("2017-01-01 12:05")
    end
  end
end
