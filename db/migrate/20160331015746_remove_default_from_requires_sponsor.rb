class RemoveDefaultFromRequiresSponsor < ActiveRecord::Migration
  def change
    change_column_null :reservation_protocols, :requires_sponsor, true
    change_column_default :reservation_protocols, :requires_sponsor, nil
  end
end
