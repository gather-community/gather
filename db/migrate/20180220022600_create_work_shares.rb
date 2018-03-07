class CreateWorkShares < ActiveRecord::Migration[5.1]
  def change
    create_table :work_shares do |t|
      t.integer :cluster_id, null: false
      t.integer :user_id, null: false
      t.integer :period_id, null: false
      t.decimal :portion, precision: 4, scale: 3, null: false, default: 1.0

      t.timestamps
    end

    add_index :work_shares, %i(period_id user_id), unique: true
    add_index :work_shares, :period_id
    add_index :work_shares, :user_id

    add_foreign_key :work_shares, :work_periods, column: "period_id"
    add_foreign_key :work_shares, :users
    add_foreign_key :work_shares, :clusters
  end
end
