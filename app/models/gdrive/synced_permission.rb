# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_synced_permissions
#
#  id               :bigint           not null, primary key
#  access_level     :string(32)       not null
#  cluster_id       :bigint           not null
#  created_at       :datetime         not null
#  external_id      :string           not null
#  google_email     :string(256)      not null
#  item_external_id :string(128)      not null
#  item_id          :integer          not null
#  updated_at       :datetime         not null
#  user_id          :integer          not null
#
module GDrive
  # Stores the permissions that have been synced to Google Drive.
  # We store these locally, rather than reading them from the API directly,
  # because there can be hundreds of permissions per item, and the API
  # is paginated and so we could end up having to make many API requests
  # just to sync a single change. The situation gets even worse if we are
  # syncing a user instead of an item. We would first have to get all the
  # items that the user has access to, and then for each item we would have
  # to get all the permissions for that item in order to find the one
  # associated for that user, since the API doesn't support searching
  # permissions by user ID. So this would be a lot of API
  # requests, and we would have to do it every time we sync a user.
  #
  # There may be cases where we need to do a full re-sync of all permissions
  # if things get out of sync. In that case, we can just delete all the
  # SyncedPermissions for a given community, delete the user-type permissions
  # on the Google side for each item, and then re-sync all the permissions.
  # This would take a bit of time, but it would be a one-time thing. I am not
  # going to build out the re-sync code for now since it might not even
  # become an issue.
  class SyncedPermission < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :gdrive_synced_permissions
    belongs_to :item, class_name: "GDrive::Item", inverse_of: :synced_permissions

    before_save do
      self.item_external_id ||= item.external_id
      self.google_email ||= user.google_email
    end

    def clone_without_external_id
      self.class.new(attributes.slice(
        *%w[user_id item_id item_external_id google_email access_level]
      ))
    end
  end
end
