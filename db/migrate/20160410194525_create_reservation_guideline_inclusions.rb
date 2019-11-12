# frozen_string_literal: true

class CreateReservationGuidelineInclusions < ActiveRecord::Migration[4.2]
  def change
    create_table :reservation_guideline_inclusions do |t|
      t.references :resource, null: false, foreign_key: true
      t.references :reservation_shared_guideline, null: false, foreign_key: true
    end

    add_index(:reservation_guideline_inclusions, %i[resource_id reservation_shared_guideline_id],
              name: "index_reservation_guideline_inclusions", unique: true)
  end
end
