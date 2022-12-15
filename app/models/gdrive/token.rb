# frozen_string_literal: true

module GDrive
  class Token < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
  end
end
