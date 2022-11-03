# frozen_string_literal: true

module GDrive
  # Stores configuration information for GDrive connection.
  class Config < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community

    def complete?
      !incomplete?
    end

    def incomplete?
      folder_id.nil?
    end
  end
end
