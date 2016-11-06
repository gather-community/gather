class CreateClusters < ActiveRecord::Migration
  def change
    create_table :clusters do |t|
      t.string :name, null: false, index: true

      t.timestamps null: false
    end
  end
end
