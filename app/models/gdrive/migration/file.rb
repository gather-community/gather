# frozen_string_literal: true

module GDrive
  module Migration
    # Stores a record of a file being migrated
    class File < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :files
    end
  end
end
