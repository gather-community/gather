# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_logs
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  created_at   :datetime         not null
#  data         :jsonb
#  level        :string           not null
#  message      :text             not null
#  operation_id :bigint           not null
#
FactoryBot.define do
  factory :gdrive_migration_log, class: "GDrive::Migration::Log" do
    association :operation, factory: :gdrive_migration_operation
    level { :info }
    message { "Message" }
    data { {foo: "bar"} }
  end
end
