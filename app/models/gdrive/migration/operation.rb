# frozen_string_literal: true

module GDrive
  module Migration
    class Operation < ApplicationRecord
      belongs_to :config, class_name: "GDrive::MigrationConfig", inverse_of: :operations
    end
  end
end
