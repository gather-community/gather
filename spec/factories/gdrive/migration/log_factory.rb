# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_log, class: "GDrive::Migration::Log" do
    association :operation, factory: :gdrive_migration_operation
    level { :info }
    message { "Message" }
    data { {foo: "bar"} }
  end
end
