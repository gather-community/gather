# frozen_string_literal: true

module GDrive
  class ItemSyncer
    attr_accessor :wrapper, :items

    def initialize(wrapper, items)
      self.wrapper = wrapper
      self.items = items
    end

    def sync
      drive_list = wrapper.service.list_drives(fields: "drives(id,name)", page_size: 100)
      all_drives_by_id = drive_list.drives.map { |d| [d.id, d] }.to_h
      Array.wrap(items).each do |drive|
        match = all_drives_by_id[drive.external_id]
        if match.nil?
          drive.not_found = true
        else
          drive.update!(name: match.name)
        end
      end
      items
    end
  end
end
