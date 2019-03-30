# frozen_string_literal: true

class MealPolicy < ApplicationPolicy
  alias meal record

  class Scope < Scope
    ASSIGNED = "EXISTS (SELECT id FROM meal_assignments
      WHERE meal_assignments.meal_id = meals.id AND meal_assignments.user_id = ?)"
    INVITED = "EXISTS (SELECT id FROM invitations
      WHERE invitations.meal_id = meals.id AND invitations.community_id = ?)"
    SIGNED_UP = "EXISTS (SELECT id FROM signups
      WHERE signups.meal_id = meals.id AND signups.household_id = ?)"

    def resolve
      if active_cluster_admin?
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

  def update?
    change_date_loc_invites? || change_formula? || change_menu? || change_workers?
  end

  def destroy?
    active_admin_or?(:meals_coordinator)
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
    meal.closed? && meal.in_past? &&
      (active_admin_or?(:biller) || meal.community.settings.meals.cooks_can_finalize? && head_cook?)
  end

  def show_reimbursement_details?
    active_admin_or?(:meals_coordinator, :biller) || head_cook?
  end

  def change_date_loc_invites?
    active_admin_or?(:meals_coordinator)
  end

  def change_formula?
    !meal.finalized? && active_admin_or?(:meals_coordinator, :biller)
  end

  def change_capacity?
    !meal.finalized? && admin_coord_or_head_cook?
  end

  def change_menu?
    !meal.finalized? && admin_coord_or_head_cook?
  end

  def change_workers?
    active_admin_or?(:meals_coordinator) || (active? && (own_community_record? || assigned?))
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
    permitted.concat(date_loc_invite_attribs) if change_date_loc_invites?
    permitted.concat(signup_attribs) if change_signups?
    permitted.concat(expense_attribs) if change_expenses?
    permitted << :formula_id if change_formula?
    permitted << :capacity if change_capacity?
    permitted
  end

  private

  def admin_coord_or_head_cook?
    active_admin_or?(:meals_coordinator) || head_cook?
  end

  def active_and_associated_or_signed_up?
    active? && associated? || signed_up? || active_admin?
  end

  def not_finalized_and_admin_coord_head_cook_or_biller?
    !meal.finalized? && (active_admin_or?(:meals_coordinator, :biller) || head_cook?)
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

  def date_loc_invite_attribs
    [:served_at, {community_boxes: [Community.all.map(&:id).map(&:to_s)]}, {resource_ids: []}]
  end

  def menu_attribs
    %i[title entrees side kids dessert notes no_allergens] << {allergens: []}
  end

  def worker_attribs
    [assignments_attributes: %i[id user_id role_id _destroy]]
  end

  def signup_attribs
    [signups_attributes: [:id, :household_id, lines_attributes: %i[id quantity item_id]]]
  end

  def expense_attribs
    [cost_attributes: %i[ingredient_cost pantry_cost payment_method]]
  end
end
