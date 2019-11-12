# frozen_string_literal: true

class AddPreNoticeToReservationProtocols < ActiveRecord::Migration[4.2]
  def change
    add_column :reservation_protocols, :pre_notice, :text
  end
end
