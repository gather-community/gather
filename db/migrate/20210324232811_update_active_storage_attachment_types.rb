# frozen_string_literal: true

class UpdateActiveStorageAttachmentTypes < ActiveRecord::Migration[6.0]
  def up
    execute("UPDATE active_storage_attachments SET record_type = 'Calendars::Node'
      WHERE record_type = 'Reservations::Resource'")
  end

  def down
    execute("UPDATE active_storage_attachments SET record_type = 'Reservations::Resource'
      WHERE record_type = 'Calendars::Node'")
  end
end
