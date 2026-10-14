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
    it "doesn't queue a notice" do
      notifier
      expect { notifier.check_and_send! }.not_to have_enqueued_job(Meals::WorkerChangeNoticeJob)
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
      it "queues a notice with what changed" do
        removed = old_assigns[0..1].map { |a| [a.user_id, a.role_id] }
        expect { notifier.check_and_send! }.to have_enqueued_job(Meals::WorkerChangeNoticeJob)
          .with(meal_id: meal.id, initiator_id: actor.id, added_ids: [new_assign.id], removed: removed)
      end
    end

    context "with privileged actor" do
      before do
        allow(notifier).to receive(:policy).and_return(double(change_workers_without_notification?: true))
      end

      it "doesn't queue a notice" do
        expect { notifier.check_and_send! }.not_to have_enqueued_job(Meals::WorkerChangeNoticeJob)
      end
    end
  end
end
