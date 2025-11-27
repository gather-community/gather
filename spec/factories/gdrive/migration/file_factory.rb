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
FactoryBot.define do
  factory :gdrive_migration_file, class: "GDrive::Migration::File" do
    association(:operation, factory: :gdrive_migration_operation)
    sequence(:external_id) { |i| "asdfafdfsd#{i}" }
    parent_id { "irais137y123" }
    owner { "foo@bar.com" }
    status { "pending" }
    name { "Stuff" }
    mime_type { "application/vnd.google-apps.document" }
    web_view_link { "https://drive.google.com/file/d/18nyjOaNbbzOWXhYRDXiiotJwwsYVvbE1/view" }
    icon_link { "https://drive-thirdparty.googleusercontent.com/32/type/application/pdf" }
    modified_at { Time.current }
  end
end
