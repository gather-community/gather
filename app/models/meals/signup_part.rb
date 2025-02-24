# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_signup_parts
#
#  id         :bigint           not null, primary key
#  count      :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  signup_id  :bigint           not null
#  type_id    :bigint           not null
#
# Indexes
#
#  index_meal_signup_parts_on_cluster_id             (cluster_id)
#  index_meal_signup_parts_on_signup_id              (signup_id)
#  index_meal_signup_parts_on_type_id                (type_id)
#  index_meal_signup_parts_on_type_id_and_signup_id  (type_id,signup_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (signup_id => meal_signups.id)
#  fk_rails_...  (type_id => meal_types.id)
#
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
