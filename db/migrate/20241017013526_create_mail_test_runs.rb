# frozen_string_literal: true

class CreateMailTestRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :mail_test_runs do |t|
      t.datetime :mail_sent_at
      t.integer :counter, default: 0

      t.timestamps
    end
  end
end
