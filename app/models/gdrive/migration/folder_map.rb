# frozen_string_literal: true

module GDrive
  module Migration
    class FolderMap < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :folder_maps
    end
  end
end
