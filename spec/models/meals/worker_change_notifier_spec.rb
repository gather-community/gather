# frozen_string_literal: true

require "rails_helper"

describe Meals::WorkerChangeNotifier do
  let(:actor) { create(:user) }
  let(:meal) { create(:meal, head_cook: create(:user), asst_cooks: [create(:user), create(:user)]) }
  let(:notifier) { described_class.new(actor, meal) }

  context "with no change" do
    it "doesn't call mailer" do
      notifier
      expect(MealMailer).not_to receive(:worker_change_notice)
      notifier.check_and_send!
    end
  end

  context "with additions and deletions" do
    let(:old_assigns) { meal.assignments.to_a }
    let(:new_assign) { meal.assignments.create!(role: old_assigns[0].role, user: create(:user)) }

    before do
      notifier
      meal.assignments.destroy(old_assigns[0])
      meal.assignments.destroy(old_assigns[1])
      new_assign
    end

    it "calls mailer with correct args" do
      expect(MealMailer).to receive(:worker_change_notice)
        .with(actor, meal, [new_assign], old_assigns[0..1]).and_return(double(deliver_now: nil))
      notifier.check_and_send!
    end
  end
end
