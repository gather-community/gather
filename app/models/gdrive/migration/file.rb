# frozen_string_literal: true

module GDrive
  module Migration
    # Stores a record of a file being migrated
    class File < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :files

      def folder?
        mime_type == GDrive::FOLDER_MIME_TYPE
      end
    end
  end
end
