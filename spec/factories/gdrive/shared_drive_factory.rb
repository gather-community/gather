# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_shared_drive, class: "GDrive::SharedDrive" do
    association :gdrive_config, factory: :gdrive_main_config
    group
    sequence(:external_id) { |i| "xxx#{i}" }
    sequence(:name) { |i| "Shared Drive #{i}" }
  end
end
