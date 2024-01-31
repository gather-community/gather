# frozen_string_literal: true

module GDrive
  # Fetches all given items, updates the stored names, checks permissions,
  # and sets error_type if appropriate.
  class ItemSyncer
    attr_accessor :wrapper, :items

    # items order should be stable across test runs or tests will flake!
    def initialize(wrapper, items)
      self.wrapper = wrapper
      self.items = items
    end

    def sync
      wrapper.batch do |service|
        items.each do |item|
          if item.drive?
            service.get_drive(item.external_id, fields: "name,capabilities(canShare)") do |result, error|
              process_item(item, result, error)
            end
          else
            service.get_file(item.external_id, fields: "name,mimeType,capabilities(canShare)", supports_all_drives: true) do |result, error|
              item.kind = (result.mime_type == GDrive::FOLDER_MIME_TYPE) ? "folder" : "file"
              process_item(item, result, error)
            end
          end
        end
      end
    end

    private

    def process_item(item, result, error)
      if error
        Rails.logger.error("Error accessing item", item_id: item.id, error: error.to_s)
        item.update!(error_type: "inaccessible")
      elsif !result.capabilities.can_share
        item.update!(name: result.name, error_type: "not_shareable")
      else
        item.update!(name: result.name, error_type: nil)
      end
    end
  end
end
