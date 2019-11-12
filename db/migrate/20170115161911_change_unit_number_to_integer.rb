# frozen_string_literal: true

class ChangeUnitNumberToInteger < ActiveRecord::Migration[4.2]
  def change
    execute('ALTER TABLE "households" ALTER COLUMN "unit_num" TYPE integer USING unit_num::integer')
  end
end
