# frozen_string_literal: true

require "rails_helper"

describe Meals::WorkerChangeNotifier do
  let(:actor) { create(:user) }
  let(:formula) { create(:meal_formula, :with_two_roles) }
  let(:meal) do
    create(:meal, formula: formula, head_cook: create(:user), asst_cooks: [create(:user), create(:user)])
  end
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

    context "with unprivileged actor" do
      it "calls mailer with correct args" do
        expect(MealMailer).to receive(:worker_change_notice)
          .with(actor, meal, [new_assign], old_assigns[0..1]).and_return(double(deliver_now: nil))
        notifier.check_and_send!
      end
    end

    context "with privileged actor" do
      before do
        allow(notifier).to receive(:policy).and_return(double(change_workers_without_notification: true))
      end

      it "doesn't call mailer" do
        expect(MealMailer).not_to receive(:worker_change_notice)
      end
    end
  end
end
