# frozen_string_literal: true

module GDrive
  # Searches Google Drive files using the Drive API fullText query syntax.
  # Filters results to drives the current user can actually access.
  class Searcher
    def initialize(wrapper:, accessible_drive_ids:, parser:)
      @wrapper = wrapper
      @accessible_drive_ids = accessible_drive_ids.to_set
      @parser = parser
    end

    def search(page_token: nil)
      return {files: [], next_page_token: nil} if @parser.blank?

      result = @wrapper.list_files(
        q: @parser.to_gdrive_q,
        fields: "nextPageToken,files(id,name,mimeType,iconLink,webViewLink,driveId,modifiedTime)",
        order_by: "modifiedTime desc",
        supports_all_drives: true,
        include_items_from_all_drives: true,
        page_size: 20,
        page_token: page_token
      )
      files = result.files.select { |f| @accessible_drive_ids.include?(f.drive_id) }
      {files: files, next_page_token: result.next_page_token}
    end
  end
end
