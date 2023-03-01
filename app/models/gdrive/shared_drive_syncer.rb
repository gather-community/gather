# frozen_string_literal: true

module GDrive
  class SharedDriveSyncer
    attr_accessor :wrapper, :shared_drives

    def initialize(wrapper, shared_drives)
      self.wrapper = wrapper
      self.shared_drives = shared_drives
    end

    def sync
      drive_list = wrapper.service.list_drives(fields: "drives(id,name)", page_size: 100)
      all_drives_by_id = drive_list.drives.map { |d| [d.id, d] }.to_h
      Array.wrap(shared_drives).each do |drive|
        match = all_drives_by_id[drive.external_id]
        if match.nil?
          drive.not_found = true
        else
          drive.update!(name: match.name)
        end
      end
      shared_drives
    end
  end
end
