# frozen_string_literal: true

module GDrive
  # Searches Google Drive files using the Drive API fullText query syntax.
  # Scopes results to files accessible to the given reader_email by including
  # a Drive-native permission filter in the query, which also ensures pagination
  # reflects only accessible results.
  class Searcher
    def initialize(wrapper:, reader_email:, drive_ids:, parser:)
      @wrapper = wrapper
      @reader_email = reader_email
      @drive_ids = drive_ids
      @parser = parser
    end

    def search(page_token: nil)
      return {files: [], next_page_token: nil} if @parser.blank?
      return {files: [], next_page_token: nil} if @drive_ids.empty?

      result = @wrapper.list_files(
        q: "#{@parser.to_gdrive_q} and #{reader_filter} and #{parents_filter}",
        fields: "nextPageToken,files(id,name,mimeType,iconLink,webViewLink,driveId,modifiedTime)",
        order_by: "modifiedTime desc",
        supports_all_drives: true,
        include_items_from_all_drives: true,
        # 500 gives effectively one-shot results for typical community drives while
        # staying well under the Drive API's 1000-item ceiling.
        page_size: 500,
        page_token: page_token
      )
      {files: result.files, next_page_token: result.next_page_token}
    end

    private

    def reader_filter
      "'#{@reader_email}' in readers"
    end

    def parents_filter
      clauses = @drive_ids.map { |id| "'#{id}' in parents" }
      "(#{clauses.join(" or ")})"
    end
  end
end
