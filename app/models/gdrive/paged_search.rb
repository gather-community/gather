# frozen_string_literal: true

module GDrive
  # Serves Drive search results a page at a time, by offset like Gather's results.
  #
  # Google's results are fetched in batches several times the page size and cached per user and query,
  # along with Google's next page token. A later page comes from the cache when it has enough files, and
  # only asks Google for more when it runs short. A first page (offset 0) always starts fresh, so a new
  # search never shows stale results. If the cache has expired, a later page refetches from the start.
  #
  # Batches can hold fewer files than requested, since the searcher drops files outside the community's
  # linked drives, so a page may take more than one request.
  class PagedSearch
    BATCH_SIZE = 50
    # Most Drive requests made for one page, so a search full of dropped files can't loop for long.
    MAX_REQUESTS = 5

    # The fields the results view uses, as a plain struct so it caches cleanly.
    DriveFile = Struct.new(:id, :name, :mime_type, :icon_link, :web_view_link, :modified_time,
      keyword_init: true)

    def initialize(searcher:, cache_key:, page_size:, expires_in:)
      @searcher = searcher
      @cache_key = cache_key
      @page_size = page_size
      @expires_in = expires_in
    end

    # Returns the page of files starting at offset, the number of files found so far, and whether there
    # are more after this page. When more is true, found is a lower bound on the total.
    def page(offset)
      state = offset.zero? ? new_state : (Rails.cache.read(@cache_key) || new_state)
      requests = 0
      # One file past the page tells us whether there's another page.
      while state[:files].size <= offset + @page_size && !state[:done] && requests < MAX_REQUESTS
        fetch_batch(state)
        requests += 1
      end
      Rails.cache.write(@cache_key, state, expires_in: @expires_in)
      {
        files: state[:files][offset, @page_size] || [],
        found: state[:files].size,
        more: state[:files].size > offset + @page_size || !state[:done]
      }
    end

    private

    def new_state
      {files: [], token: nil, done: false}
    end

    def fetch_batch(state)
      result = @searcher.search(page_token: state[:token], page_size: BATCH_SIZE)
      state[:files].concat(result[:files].map { |f| to_drive_file(f) })
      state[:token] = result[:next_page_token]
      state[:done] = state[:token].nil?
    end

    def to_drive_file(file)
      DriveFile.new(id: file.id, name: file.name, mime_type: file.mime_type, icon_link: file.icon_link,
        web_view_link: file.web_view_link, modified_time: file.modified_time)
    end
  end
end
