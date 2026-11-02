# frozen_string_literal: true

module Meals
  # Tells everyone with a stake in a meal team that the team changed.
  # Queued by WorkerChangeNotifier, which works out what changed while handling the request.
  class WorkerChangeNoticeJob < ApplicationJob
    # Removed assignments are already deleted, so they're passed as [user_id, role_id] pairs.
    def perform(meal_id:, initiator_id:, added_ids:, removed:)
      with_object_in_cluster_context(klass: Meal, id: meal_id) do |meal|
        initiator = User.find(initiator_id)
        added = meal.assignments.where(id: added_ids).to_a
        removed = removed
          .map { |user_id, role_id| Assignment.new(meal: meal, user_id: user_id, role_id: role_id) }
          .select(&:user)
        targets = interested_parties(meal, initiator, removed)
        each_notification_recipient(targets, kind: :meal_worker_change, data: {meal_id: meal_id}) do |user|
          MealMailer.with(recipient: user).worker_change_notice(initiator, meal, added, removed).deliver_now
        end
      end
    end

    private

    # Everyone with a stake in the meal team, before Notifications::Recipients filters them.
    def interested_parties(meal, initiator, removed)
      (meal.assignments.to_a + removed).map(&:user) + [initiator] +
        User.with_meals_coordinator_role.in_community(meal.community).to_a
    end
  end
end
