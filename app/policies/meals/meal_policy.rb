# frozen_string_literal: true

module Meals
  class MealPolicy < ApplicationPolicy
    alias meal record

    class Scope < Scope
      ASSIGNED = "EXISTS (SELECT id FROM meal_assignments
        WHERE meal_assignments.meal_id = meals.id AND meal_assignments.user_id = ?)"
      INVITED = "EXISTS (SELECT id FROM meal_invitations
        WHERE meal_invitations.meal_id = meals.id AND meal_invitations.community_id = ?)"
      SIGNED_UP = "EXISTS (SELECT id FROM meal_signups
        WHERE meal_signups.meal_id = meals.id AND meal_signups.household_id = ?)"

      def resolve
        # If user is nil, it means this Scope class is being used for getting a meal listing not linked
        # to a particular user. This is useful in cases like exporting for a shared calendar.
        # Since we don't have a user to check assigned/invited/signed up, we just return all meals
        # and leave it up to the model class to filter meals appropriately beyond that.
        if user.nil? || active_cluster_admin?
          scope
        elsif user.active?
          scope.where("#{ASSIGNED} OR #{INVITED} OR #{SIGNED_UP}",
                      user.id, user.community_id, user.household_id)
        else
          scope.where(SIGNED_UP, user.household_id)
        end
      end
    end

    def index?
      active_in_cluster?
    end

    def show?
      active_and_associated_or_signed_up?
    end

    def report?
      index?
    end

    def jobs?
      index?
    end

    def create?
      active_admin_or?(:meals_coordinator)
    end

    def import?
      active_admin_or?(:meals_coordinator)
    end

    def update?
      change_date_loc? || change_invites? || change_formula? || change_menu? || change_workers?
    end

    def destroy?
      active_admin_or?(:meals_coordinator) && !meal.finalized?
    end

    def summary?
      active_cluster_admin? || active_and_associated_or_signed_up?
    end

    def close?
      admin_coord_or_head_cook? && meal.open?
    end

    def cancel?
      admin_coord_or_head_cook? && !meal.cancelled? && !meal.finalized?
    end

    def reopen?
      admin_coord_or_head_cook? && meal.closed? && !meal.day_in_past?
    end

    def finalize?
      meal.closed? && meal.in_past? && admin_or_biller_or_head_cook_and_can_finalize?
    end

    def unfinalize?
      meal.finalized? && admin_or_biller_or_head_cook_and_can_finalize? && meal.transactions.none?(&:statement?)
    end

    def finalize_complete?
      meal.finalized? && admin_or_biller_or_head_cook_and_can_finalize?
    end

    def show_reimbursement_details?
      active_admin_or?(:meals_coordinator, :biller) || head_cook?
    end

    def change_date_loc?
      active_admin_or?(:meals_coordinator)
    end

    def change_invites?
      active_admin_or?(:meals_coordinator) || (meal.community.settings.meals.cooks_can_change_invites? && head_cook?)
    end

    def change_formula?
      meal.signups.none? && not_finalized_and_admin_coord_head_cook_or_biller?
    end

    def change_capacity_close_time?
      !meal.finalized? && admin_coord_or_head_cook?
    end

    def change_menu?
      !meal.finalized? && admin_coord_or_head_cook?
    end

    def change_workers?
      active_admin_or?(:meals_coordinator) || (active? && (record_tied_to_user_community? || assigned?))
    end

    def change_workers_without_notification?
      active_admin_or?(:meals_coordinator)
    end

    # Whether someone can edit signups for _anyone_, not just themselves.
    def change_signups?
      not_finalized_and_admin_coord_head_cook_or_biller?
    end

    def change_expenses?
      not_finalized_and_admin_coord_head_cook_or_biller?
    end

    def send_message?
      active_admin_or?(:meals_coordinator) || assigned?
    end

    def permitted_attributes
      permitted = []
      permitted.concat(worker_attribs) if change_workers?
      permitted.concat(menu_attribs) if change_menu?
      permitted.concat(date_loc_attribs) if change_date_loc?
      permitted.concat(invite_attribs) if change_invites?
      permitted.concat(signup_attribs) if change_signups?
      permitted.concat(expense_attribs) if change_expenses?
      permitted << :formula_id if change_formula?
      permitted.concat(capacity_close_time_attribs) if change_capacity_close_time?
      permitted << :source_form if permitted.any?
      permitted
    end

    private

    def admin_coord_or_head_cook?
      active_admin_or?(:meals_coordinator) || head_cook?
    end

    def active_and_associated_or_signed_up?
      (active? && associated?) || signed_up? || active_admin?
    end

    def not_finalized_and_admin_coord_head_cook_or_biller?
      !meal.finalized? && (active_admin_or?(:meals_coordinator, :biller) || head_cook?)
    end

    def admin_or_biller_or_head_cook_and_can_finalize?
      active_admin_or?(:biller) || (meal.community.settings.meals.cooks_can_finalize? && head_cook?)
    end

    def associated?
      invited? || assigned? || signed_up?
    end

    def invited?
      meal.communities.include?(user.community)
    end

    def assigned?
      meal.assignments.any? { |a| a.user == user }
    end

    def signed_up?
      meal.signups.any? { |s| s.household == user.household }
    end

    def head_cook?
      active? && user == meal.head_cook
    end

    def date_loc_attribs
      [:served_at, {calendar_ids: []}]
    end

    def invite_attribs
      [{community_boxes: [Community.all.map(&:id).map(&:to_s)]}]
    end

    def menu_attribs
      %i[title entrees side kids dessert notes no_allergens] << {allergens: []}
    end

    def capacity_close_time_attribs
      %i[capacity auto_close_time]
    end

    def worker_attribs
      [assignments_attributes: %i[id user_id role_id _destroy]]
    end

    def signup_attribs
      [signups_attributes: [:id, :household_id, {parts_attributes: %i[id type_id count _destroy]}]]
    end

    def expense_attribs
      [cost_attributes: %i[ingredient_cost pantry_cost payment_method reimbursee_id]]
    end
  end
end
