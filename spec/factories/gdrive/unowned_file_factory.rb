# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_unowned_file, class: "GDrive::UnownedFile" do
    association(:gdrive_config, factory: :gdrive_migration_config)
    external_id { "asdfafdfsd" }
    owner { "foo@bar.com" }
    data { {name: "Foo"} }
  end
end
