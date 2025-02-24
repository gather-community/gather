# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_invitations
#
#  id           :integer          not null, primary key
#  cluster_id   :integer          not null
#  community_id :integer          not null
#  meal_id      :integer          not null
#
# Indexes
#
#  index_meal_invitations_on_cluster_id                (cluster_id)
#  index_meal_invitations_on_community_id              (community_id)
#  index_meal_invitations_on_community_id_and_meal_id  (community_id,meal_id) UNIQUE
#  index_meal_invitations_on_meal_id                   (meal_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (meal_id => meals.id)
#
  # Join model for Meals and Communities
  class Invitation < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :meal, class_name: "Meals::Meal"
    belongs_to :community
  end
end
