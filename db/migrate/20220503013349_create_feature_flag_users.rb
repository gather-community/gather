# frozen_string_literal: true

class CreateFeatureFlagUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :feature_flag_users do |t|
      t.references :feature_flag, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.index %i[feature_flag_id user_id], unique: true
      t.timestamps
    end
  end
end
