# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_files
#
#  id                        :bigint           not null, primary key
#  cluster_id                :bigint           not null
#  created_at                :datetime         not null
#  error_message             :string(255)
#  error_type                :string
#  external_id               :string           not null
#  icon_link                 :string           not null
#  migrated_parent_id        :string
#  mime_type                 :string(255)      not null
#  modified_at               :datetime         not null
#  name                      :text             not null
#  operation_id              :bigint           not null
#  owner                     :string           not null
#  parent_id                 :string           not null
#  shortcut_target_id        :string(128)
#  shortcut_target_mime_type :string(128)
#  status                    :string           not null
#  updated_at                :datetime         not null
#  web_view_link             :string           not null
#
require "rails_helper"

describe GDrive::Migration::File do
  it "has a valid factory" do
    create(:gdrive_migration_file)
  end
end
