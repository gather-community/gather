class AddHostCommunityIdToMeals < ActiveRecord::Migration
  def change
    add_column :meals, :host_community_id, :integer, index: true
    add_foreign_key :meals, :communities, column: :host_community_id
    Meal.all.each do |m|
      m.host_community = m.head_cook.community
      m.save(validate: false)
    end
    change_column_null :meals, :host_community_id, false
  end
end
