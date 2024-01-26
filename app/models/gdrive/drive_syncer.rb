# frozen_string_literal: true

module GDrive
  # Fetches all shared drives and updates the stored names.
  # Assumes there are less than 100 shared drives in the connected Workspace.
  class DriveSyncer
    attr_accessor :wrapper, :drives

    def initialize(wrapper, drives)
      self.wrapper = wrapper
      self.drives = drives
    end

    def sync
      drive_list = wrapper.list_drives(fields: "drives(id,name)", page_size: 100)
      all_drives_by_id = drive_list.drives.index_by(&:id)
      Array.wrap(drives).each do |drive|
        match = all_drives_by_id[drive.external_id]
        if match.nil?
          drive.error_type = "inaccessible"
        else
          drive.update!(name: match.name)
        end
      end
      drives
    end
  end
end
