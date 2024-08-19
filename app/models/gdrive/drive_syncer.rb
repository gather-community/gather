# frozen_string_literal: true

module GDrive
  # Fetches all shared drives and updates the stored names.
  # Assumes there are less than 100 shared drives in the connected Workspace.
  class DriveSyncer
    attr_accessor :wrapper, :drive_items

    def initialize(wrapper, drive_items)
      self.wrapper = wrapper
      self.drive_items = drive_items
    end

    def sync
      # Fetch all drive API objects for wrapper. Assumes there aren't more than 100.
      drive_list = wrapper.list_drives(fields: "drives(id,name)", page_size: 100)
      all_drives_by_id = drive_list.drives.index_by(&:id)

      # Update all passed drive items with fetched data.
      Array.wrap(drive_items).each do |drive_item|
        match = all_drives_by_id[drive_item.external_id]
        if match.nil?
          drive_item.error_type = "inaccessible"
        else
          drive_item.update!(name: match.name)
        end
      end
    end
  end
end
