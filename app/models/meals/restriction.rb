# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_restrictions
#
#  id           :bigint           not null, primary key
#  absence      :string           not null
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  contains     :string           not null
#  created_at   :datetime         not null
#  deactivated  :boolean          default(FALSE), not null
#  updated_at   :datetime         not null
#
module Meals
  class Restriction < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :restrictions

    validates :contains, :absence, presence: true

    def deactivated?
      deactivated
    end
  end
end
