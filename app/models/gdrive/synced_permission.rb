# frozen_string_literal: true

module GDrive
  class SyncedPermission < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :gdrive_synced_permissions
    belongs_to :item, class_name: "GDrive::Item", inverse_of: :synced_permissions
  end
end
