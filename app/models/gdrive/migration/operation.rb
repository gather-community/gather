# frozen_string_literal: true

module GDrive
  module Migration
    class Operation < ApplicationRecord
      belongs_to :config, class_name: "GDrive::MigrationConfig", inverse_of: :operations
      has_many :files, class_name: "GDrive::Migration::File",
        inverse_of: :operation, dependent: :destroy
    end
  end
end
