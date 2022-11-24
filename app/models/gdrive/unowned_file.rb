# frozen_string_literal: true

module GDrive
  # Stores a record of an unowned GDrive file
  class UnownedFile < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
  end
end
