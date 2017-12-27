class AddAbbrvToCommunities < ActiveRecord::Migration[4.2]
  def change
    unless column_exists?(:communities, :abbrv)
      add_column :communities, :abbrv, :string
      Community.where(name: 'Touchstone').first.update_attribute(:abbrv, 'TS')
      Community.where(name: 'Great Oak').first.update_attribute(:abbrv, 'GO')
      Community.where(name: 'Sunward').first.update_attribute(:abbrv, 'SW')
      change_column_null :communities, :abbrv, false
    end
  end
end
