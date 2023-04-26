# frozen_string_literal: true

require "rails_helper"

describe GDrive::SyncedPermission do
  it "has a valid factory" do
    create(:gdrive_synced_permission)
  end
end
