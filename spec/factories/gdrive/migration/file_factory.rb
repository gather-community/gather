# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_file, class: "GDrive::Migration::File" do
    association(:operation, factory: :gdrive_migration_operation)
    external_id { "asdfafdfsd" }
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
