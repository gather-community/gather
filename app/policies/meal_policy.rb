# frozen_string_literal: true

class MealPolicy < ApplicationPolicy
  alias meal record

  class Scope < Scope
    ASSIGNED = "EXISTS (SELECT id FROM assignments
      WHERE assignments.meal_id = meals.id AND assignments.user_id = ?)"
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

  # We let anyone from host community (or assignees from outside) do this
  # so they can change assignments.
  def update?
    active_admin_or?(:meals_coordinator) || (active? && (own_community_record? || assigned?))
  end

  def destroy?
    active_admin_or?(:meals_coordinator)
  end

  def summary?
    active_and_associated_or_signed_up?
  end

  def close?
    active_admin_or_coordinator_or_head_cook? && meal.open?
  end

  def cancel?
    active_admin_or_coordinator_or_head_cook? && !meal.cancelled? && !meal.finalized?
  end

  def reopen?
    active_admin_or_coordinator_or_head_cook? && meal.closed? && !meal.day_in_past?
  end

  def finalize?
    active_admin_or?(:biller) && meal.closed? && meal.in_past?
  end

  # Means they can peform the fundamental tasks (set date, communities, etc.)
  def update_general?
    active_admin_or?(:meals_coordinator)
  end

  def update_menu?
    active_admin_or_coordinator_or_head_cook?
  end

  def update_formula?
    !meal.finalized? && update_general?
  end

  def send_message?
    active_admin_or?(:meals_coordinator) || assigned?
  end

  def permitted_attributes
    # Anybody that can update a meal can change the assignments.
    permitted = [{
      head_cook_assign_attributes: %i[id user_id],
      asst_cook_assigns_attributes: %i[id user_id _destroy],
      table_setter_assigns_attributes: %i[id user_id _destroy],
      cleaner_assigns_attributes: %i[id user_id _destroy]
    }]
    permitted.concat(menu_attribs) if update_menu?
    permitted.concat([:served_at, resource_ids: []]) if update_general?
    permitted << :formula_id if update_formula?
    permitted
  end

  private

  def active_admin_or_coordinator_or_head_cook?
    active_admin_or?(:meals_coordinator) || active? && head_cook?
  end

  def active_and_associated_or_signed_up?
    active? && associated? || signed_up? || active_admin?
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
    user == meal.head_cook
  end

  def menu_attribs
    Meal::ALLERGENS.map { |a| :"allergen_#{a}" } +
      [:title, :capacity, :entrees, :side, :kids, :dessert, :notes,
       {community_boxes: [Community.all.map(&:id).map(&:to_s)]}]
  end
end
