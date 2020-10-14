# frozen_string_literal: true

class CreateMissingAccounts < ActiveRecord::Migration[6.0]
  def up
    query = <<-SQL
      INSERT INTO accounts(household_id, community_id, created_at, updated_at, cluster_id)
      SELECT households.id, households.community_id, NOW(), NOW(), households.cluster_id
        FROM households
        WHERE NOT EXISTS (
          SELECT id FROM accounts
            WHERE household_id = households.id AND community_id = households.community_id
        )
    SQL
    execute(query)
  end
end
