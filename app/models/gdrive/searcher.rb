# frozen_string_literal: true

module GDrive
  # Searches Google Drive files using the Drive API fullText query syntax.
  # Scopes results to files accessible to the given reader_email by including
  # a Drive-native permission filter in the query, which also ensures pagination
  # reflects only accessible results.
  #
  # Searches every shared drive the community's Google account can see, then keeps only files in the
  # community's linked drives. Drive's query language can't say "anywhere in this drive": `in parents`
  # only matches a folder's direct children, which missed every file in a subfolder.
  class Searcher
    # The file types the search can be limited to. "other" is any file that isn't one of the rest.
    FILE_TYPES = (Search::QueryParser::MIME_TYPES.keys + ["other"]).freeze

    # file_types limits the results to those types (see FILE_TYPES). All of them, the default, means any file.
    def initialize(wrapper:, reader_email:, drive_ids:, parser:, file_types: FILE_TYPES)
      @wrapper = wrapper
      @reader_email = reader_email
      @drive_ids = drive_ids
      @parser = parser
      @file_types = file_types
    end

    def search(page_token: nil, page_size: 50)
      return {files: [], next_page_token: nil} if @parser.blank?
      return {files: [], next_page_token: nil} if @drive_ids.empty? || @file_types.empty?

      result = @wrapper.list_files(
        q: [@parser.to_gdrive_q, reader_filter, file_type_filter].compact.join(" and "),
        fields: "nextPageToken,files(id,name,mimeType,iconLink,webViewLink,driveId,modifiedTime)",
        order_by: "modifiedTime desc",
        corpora: "allDrives",
        supports_all_drives: true,
        include_items_from_all_drives: true,
        page_size: page_size,
        page_token: page_token
      )
      files = result.files.select { |f| @drive_ids.include?(f.drive_id) }
      {files: files, next_page_token: result.next_page_token}
    end

    private

    def file_type_filter
      return if (FILE_TYPES - @file_types).empty?
      mime_types = Search::QueryParser::MIME_TYPES
      clauses = (@file_types - ["other"]).map { |t| "mimeType = '#{mime_types.fetch(t)}'" }
      if @file_types.include?("other")
        clauses << "(#{mime_types.values.map { |m| "mimeType != '#{m}'" }.join(" and ")})"
      end
      "(#{clauses.join(" or ")})"
    end

    def reader_filter
      "'#{@reader_email}' in readers"
    end
  end
end
