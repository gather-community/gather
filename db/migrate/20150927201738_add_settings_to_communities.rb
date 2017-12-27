class AddSettingsToCommunities < ActiveRecord::Migration[4.2]
  def change
    add_column :communities, :settings, :text, default: "{}"
    Community.all.each do |c|
      c.update_attribute(:settings,
        case c.name
        when "Touchstone"
          {meal_reimb_dropoff_loc: "in the lockbox by the Touchstone Common House office (near the east bathroom)"}
        when "Great Oak"
          {meal_reimb_dropoff_loc: "in the cubby for GO Unit 19 (Kathy) in the Great Oak Common House"}
        when "Sunward"
          {meal_reimb_dropoff_loc: "in the Common Kitchen cubby in the Sunward Common House"}
        else
          c.settings # No change
        end)
    end
  end
end
