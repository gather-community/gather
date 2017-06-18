class AddPreNoticeToReservationProtocols < ActiveRecord::Migration
  def change
    add_column :reservation_protocols, :pre_notice, :text
  end
end
