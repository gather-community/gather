# frozen_string_literal: true

module GDrive
  # Stores configuration information for GDrive connection.
  class Config < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
  end
end
