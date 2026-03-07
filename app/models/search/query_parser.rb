# frozen_string_literal: true

module Search
  # Parses a shared search query string into components usable by both
  # Elasticsearch (wiki) and the Google Drive API.
  #
  # Supported syntax:
  #   solar panels            - full-text search for both words
  #   "solar panels"          - exact phrase match
  #   title:minutes           - restrict to title/name field only
  #   title:"budget 2024"     - exact phrase in title/name
  #   type:doc                - Drive only: restrict by MIME type (doc/sheet/slide/folder/pdf)
  #
  # type: is silently ignored for wiki results.
  class QueryParser
    MIME_TYPES = {
      "doc"    => "application/vnd.google-apps.document",
      "sheet"  => "application/vnd.google-apps.spreadsheet",
      "slide"  => "application/vnd.google-apps.presentation",
      "folder" => "application/vnd.google-apps.folder",
      "pdf"    => "application/pdf"
    }.freeze

    attr_reader :full_text_terms, :title_terms, :type_filter

    def initialize(raw)
      @full_text_terms = []
      @title_terms = []
      @type_filter = nil
      parse(raw.to_s.strip)
    end

    def blank?
      full_text_terms.empty? && title_terms.empty?
    end

    def to_gdrive_q
      parts = ["trashed = false"]
      parts.concat(title_terms.map { |t| "name contains '#{escape(t)}'" })
      parts.concat(full_text_terms.map { |t| "fullText contains '#{escape(t)}'" })
      parts << "mimeType = '#{MIME_TYPES[type_filter]}'" if MIME_TYPES.key?(type_filter.to_s)
      parts.join(" and ")
    end

    def to_es_query(community_id:)
      must = []
      if full_text_terms.any?
        must << {
          multi_match: {
            query: full_text_terms.join(" "),
            fields: ["title^3", "content"],
            type: "best_fields"
          }
        }
      end
      title_terms.each { |t| must << {match: {title: t}} }

      {
        query: {
          bool: {
            filter: [{term: {community_id: community_id}}],
            must: must.presence || [{match_all: {}}]
          }
        },
        highlight: {
          pre_tags: ["<mark>"],
          post_tags: ["</mark>"],
          fields: {
            content: {fragment_size: 200, number_of_fragments: 1},
            title: {}
          }
        },
        size: 20
      }
    end

    private

    def parse(raw)
      raw = raw.gsub(/title:"([^"]+)"/) { @title_terms << $1; "" }
               .gsub(/title:(\S+)/)     { @title_terms << $1; "" }
               .gsub(/type:(\S+)/)      { @type_filter = $1.downcase; "" }
               .gsub(/"([^"]+)"/)       { @full_text_terms << $1; "" }
      @full_text_terms.concat(raw.split.reject(&:empty?))
    end

    def escape(term)
      term.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")
    end
  end
end
