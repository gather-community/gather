# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_invitations
#
#  id           :integer          not null, primary key
#  cluster_id   :integer          not null
#  community_id :integer          not null
#  meal_id      :integer          not null
#
module Meals
  # Join model for Meals and Communities
  class Invitation < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :meal, class_name: "Meals::Meal"
    belongs_to :community
  end
end
