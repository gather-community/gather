class AddReservationSponsorStuff < ActiveRecord::Migration
  def change
    rename_column :reservations, :user_id, :reserver_id
    add_column :reservations, :sponsor_id, :integer
    add_index :reservations, :sponsor_id
    add_foreign_key :reservations, :users, column: "sponsor_id"
    add_column :reservation_protocols, :requires_sponsor, :boolean, null: false, default: true
  end
end
