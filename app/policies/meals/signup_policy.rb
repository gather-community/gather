# frozen_string_literal: true

module Meals
  class SignupPolicy < ApplicationPolicy
    alias signup record

    delegate :meal, to: :signup

    def create?
      active? && invited? && meal.open? && !meal.cancelled? && !meal.full? && !meal.in_past?
    end

    def update?
      invited? && meal.open? && !meal.in_past?
    end

    def permitted_attributes
      [:id, :household_id, :meal_id, :takeout, :comments, parts_attributes: %i[id type_id count _destroy]]
    end

    # :diner_counts is a sentinel expanded by Meals::SignupCsvExporter into one column per active
    # meal type. This method deliberately does no role checking: it's called on a sample signup
    # attached to a sample meal, which has no invitations, so record_tied_to_user_community? (and
    # thus active_admin_or?) would silently be false. Access to the signups export is gated by
    # Meals::MealPolicy#export_signups? in the controller.
    def exportable_attributes
      attribs = %i[meal_id served_at meal_title calendars formula]
      attribs.concat(%i[community_id community_name]) if multi_community?
      attribs.concat(%i[household_id household_name diner_counts total takeout comments created_at])
    end

    private

    def invited?
      # Compare IDs to prevent N+1 in meals index
      meal.invitations.any? { |invitation| invitation.community_id == user.community_id }
    end
  end
end
