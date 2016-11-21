require 'rails_helper'

describe Meals::ClosePastMealsJob do
  let!(:meal1) { create(:meal, status: "open", served_at: Time.now - 3.hours) }
  let!(:meal2) { create(:meal, status: "open", served_at: Time.now - 1.hour) }
  let!(:meal3) { create(:meal, status: "open", served_at: Time.now + 1.hour) }

  it "closes meals more than 3 hours in the past" do
    Meals::ClosePastMealsJob.new.perform
    expect(meal1.reload.closed?).to be true
    expect(meal2.reload.open?).to be true
    expect(meal3.reload.open?).to be true
  end
end
