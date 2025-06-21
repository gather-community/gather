# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_restrictions
#
#  id             :bigint           not null, primary key
#  contains       :string(64)       not null
#  absence        :string(64)       not null
#  cluster_id     :bigint           not null
#  deactivated_at :datetime
#  deactivated    :boolean          not null
#  community_id   :bigint           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
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
