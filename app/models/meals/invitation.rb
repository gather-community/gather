# frozen_string_literal: true

module Meals
  # Join model for Meals and Communities
  class Invitation < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :meal
    belongs_to :community
  end
end
