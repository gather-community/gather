class AddHostCommunityIdToMeals < ActiveRecord::Migration[4.2]
  def change
    add_column :meals, :community_id, :integer, index: true
    add_foreign_key :meals, :communities, column: :community_id
    Meal.all.each do |m|
      m.community = m.head_cook.community
      m.save(validate: false)
    end
    change_column_null :meals, :community_id, false
  end
end
