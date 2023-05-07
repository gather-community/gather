class AddPronounsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :pronouns, :string, limit: 24
  end
end
