# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_signup_parts
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  count      :integer          not null
#  created_at :datetime         not null
#  signup_id  :bigint           not null
#  type_id    :bigint           not null
#  updated_at :datetime         not null
#  user_id    :bigint
#  set_place  :boolean          default(TRUE)
#  save_plate :boolean          default(FALSE)
#
module Meals
  # Joins a meal signup object to its constituent meal types.
  class SignupPart < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :type
    belongs_to :signup, class_name: "Meals::Signup", inverse_of: :parts

    delegate :zero?, to: :count
    delegate :name, to: :type, prefix: true
    delegate :household_id, to: :signup

    # Sorts by rank of the associated meal_formula_part
    def self.by_rank
      joins(signup: :meal)
        .joins(Arel.sql("LEFT JOIN meal_formula_parts ON meal_formula_parts.formula_id = meals.formula_id
          AND meal_formula_parts.type_id = meal_signup_parts.type_id"))
        .order(FormulaPart.arel_table[:rank])
    end
  end
end
