class CreateCommunities < ActiveRecord::Migration
  def change
    create_table :communities do |t|
      t.string :name, null: false

      t.timestamps null: false
    end
  end
end
