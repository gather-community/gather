class ChangeHouseholdCols < ActiveRecord::Migration[4.2]
  def change
    rename_column :households, :name, :suffix
    change_column :households, :suffix, :string, null: true
    Household.all.each do |h|
      h.suffix.gsub!(/\d/, '')
      h.suffix = nil if h.suffix.blank?
      h.save(validate: false)
    end
  end
end
