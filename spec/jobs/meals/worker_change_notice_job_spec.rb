# frozen_string_literal: true

require "rails_helper"

describe Meals::WorkerChangeNoticeJob do
  include_context "jobs"

  let(:formula) { create(:meal_formula, :with_two_roles) }
  let(:head_cook) { create(:user) }
  let(:asst_cook) { create(:user, first_name: "Stays") }
  let(:meal) { create(:meal, formula: formula, head_cook: head_cook, asst_cooks: [asst_cook]) }
  let!(:initiator) { create(:user) }
  let(:added_user) { create(:user, first_name: "Joins") }
  let!(:removed_user) { create(:user, first_name: "Leaves") }
  let(:asst_role) { formula.roles.detect { |r| !r.head_cook? } }
  let!(:added) { meal.assignments.create!(role: asst_role, user: added_user) }
  let!(:coordinator) { create(:meals_coordinator) }
  let!(:opted_out_coordinator) do
    create(:meals_coordinator, notification_prefs: {"meal_worker_change" => {"email" => false}})
  end
  let!(:decoy) { create(:user) }

  subject(:job) do
    described_class.new(meal_id: meal.id, initiator_id: initiator.id, added_ids: [added.id],
      removed: [[removed_user.id, asst_role.id]])
  end

  before { ActionMailer::Base.deliveries.clear }

  it "sends each interested person their own notice" do
    perform_job
    recipients = [head_cook, asst_cook, added_user, removed_user, initiator, coordinator]
    expect(ActionMailer::Base.deliveries.map(&:to)).to match_array(recipients.map { |u| [u.email] })
  end

  it "describes the change" do
    perform_job
    body = ActionMailer::Base.deliveries.first.body.encoded
    expect(body).to include("Joins", "Leaves")
  end
end
