# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_types
#
#  id             :bigint           not null, primary key
#  category       :string(32)
#  cluster_id     :bigint           not null
#  community_id   :bigint           not null
#  created_at     :datetime         not null
#  deactivated_at :datetime
#  name           :string(32)       not null
#  updated_at     :datetime         not null
#
module Meals
  class TypeSerializer < ApplicationSerializer
    attributes :id, :name, :category
  end
end
