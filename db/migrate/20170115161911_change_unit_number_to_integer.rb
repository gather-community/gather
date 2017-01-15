class ChangeUnitNumberToInteger < ActiveRecord::Migration
  def change
    execute('ALTER TABLE "households" ALTER COLUMN "unit_num" TYPE integer USING unit_num::integer')
  end
end
