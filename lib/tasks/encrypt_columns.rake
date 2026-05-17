# frozen_string_literal: true

namespace :db do
  namespace :encryption do
    desc "Encrypt existing plaintext values for sensitive columns"
    task encrypt_sensitive: :environment do
      {
        Cluster => %i[sso_secret],
        Community => %i[sso_secret calendar_token],
        GDrive::Config => %i[client_secret],
        GDrive::Token => %i[data],
        GDrive::Migration::Operation => %i[webhook_secret],
        User => %i[medical allergies doctor],
        People::EmergencyContact => %i[main_phone alt_phone]
      }.each do |model, columns|
        count = ActsAsTenant.without_tenant { model.count }
        puts "Encrypting #{model} (#{count} records)..."
        ActsAsTenant.without_tenant do
          model.find_each do |record|
            updates = columns.filter_map { |col|
              val = record.public_send(col)
              [col, val] if val.present?
            }.to_h
            record.update_columns(**updates) if updates.any?
          end
        end
        puts "  Done"
      end
    end
  end
end
