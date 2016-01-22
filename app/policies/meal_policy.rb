class MealPolicy < ApplicationPolicy
  alias_method :meal, :record

  class Scope < Scope
    def resolve
      scope.where("EXISTS (SELECT id FROM assignments
        WHERE assignments.meal_id = meals.id AND assignments.user_id = ?) OR
          EXISTS (SELECT id FROM invitations
            WHERE invitations.meal_id = meals.id AND invitations.community_id = ?) OR
          EXISTS (SELECT id FROM signups WHERE signups.meal_id = meals.id AND signups.household_id = ?)",
        user.id, user.community_id, user.household_id)
    end
  end

  def index?
    true
  end

  def show?
    associated?
  end

  # Means they can see the work shifts for the meal
  def work?
    associated?
  end

  def create?
    user.admin?
  end

  def update?
    host? || assigned?
  end

  # Means they can peform the fundamental tasks (set date, communities, etc.)
  def administer?
    user.admin? && host?
  end

  def destroy?
    administer?
  end

  def summary?
    hosting_admin_or_head_cook?
  end

  def set_menu?
    hosting_admin_or_head_cook?
  end

  def close?
    hosting_admin_or_head_cook?
  end

  def reopen?
    hosting_admin_or_head_cook?
  end

  def finalize?
    host? && (user.admin? || user.biller?)
  end

  def permitted_attributes
    # Anybody that can update a meal can change the assignments.
    permitted = [{
      :head_cook_assign_attributes => [:id, :user_id],
      :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
      :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
    }]

    if set_menu?
      allergens = Meal::ALLERGENS.map{ |a| :"allergen_#{a}" }
      permitted += allergens + [:title, :capacity, :entrees, :side, :kids, :dessert, :notes,
        { :community_boxes => [Community.all.map(&:id).map(&:to_s)] }
      ]
    end

    if administer?
      permitted += [:discount, :served_at, :location_id]
    end

    permitted
  end

  private

  def hosting_admin_or_head_cook?
    user.admin? && host? || head_cook?
  end

  def host?
    user.community == meal.host_community
  end

  def associated?
    invited? || assigned? || signed_up?
  end

  def invited?
    meal.communities.include?(user.community)
  end

  def assigned?
    meal.assignments.any?{ |a| a.user == user }
  end

  def signed_up?
    meal.households.any?{ |h| user.household }
  end

  def head_cook?
    user == meal.head_cook
  end
end