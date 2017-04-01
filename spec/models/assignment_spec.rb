require "rails_helper"

describe Assignment do
  describe "timing" do
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
