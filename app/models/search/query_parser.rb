# frozen_string_literal: true

module Search
  # Parses a shared search query string into components usable by both
  # Elasticsearch and the Google Drive API.
  #
  # Supported syntax:
  #   solar panels            - full-text search for both words
  #   "solar panels"          - exact phrase match
  #   sol*                    - words starting with "sol"
  #   title:minutes           - restrict to title/name field only
  #   title:"budget 2024"     - exact phrase in title/name
  #   type:doc                - Drive only: restrict by MIME type (doc/sheet/slide/folder/pdf)
  #
  # type: is silently ignored for Gather results.
  class QueryParser
    MIME_TYPES = {
      "doc" => "application/vnd.google-apps.document",
      "sheet" => "application/vnd.google-apps.spreadsheet",
      "slide" => "application/vnd.google-apps.presentation",
      "folder" => "application/vnd.google-apps.folder",
      "pdf" => "application/pdf"
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
      parts.concat(full_text_terms.map do |t|
        # Drive's full-text search only matches whole words, but its name search matches prefixes.
        wildcard?(t) ? "name contains '#{escape(t.delete_suffix("*"))}'" : "fullText contains '#{escape(t)}'"
      end)
      parts << "mimeType = '#{MIME_TYPES[type_filter]}'" if MIME_TYPES.key?(type_filter.to_s)
      parts.join(" and ")
    end

    # rubocop:disable Metrics/MethodLength
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
          # HTML-escape the source text in fragments, since the views render them as raw HTML.
          encoder: "html",
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
    # rubocop:enable Metrics/MethodLength

    # Multi-index Gather search across all indexed models.
    # community_id is the integer ID of the current community.
    # extra_filters are additional bool filter clauses, e.g. from Search::Visibility.
    # Includes results where community_id matches (single-community models) OR
    # community_ids contains the ID (multi-community models like Groups::Group).
    # rubocop:disable Metrics/MethodLength
    def to_gather_query(community_id:, kinds: nil, extra_filters: [])
      # Every word or quoted phrase must match, each in any one field.
      must = full_text_terms.map { |t| term_query(t, GATHER_FIELDS) } +
        title_terms.map { |t| term_query(t, TITLE_FIELDS) }

      community_filter = {
        bool: {
          should: [
            {term: {community_id: community_id}},
            {term: {community_ids: community_id}}
          ],
          minimum_should_match: 1
        }
      }

      filter = [community_filter, *extra_filters]
      filter << {terms: {kind: kinds}} if kinds.present?

      {
        query: {
          bool: {
            filter: filter,
            must: must.presence || [{match_all: {}}],
            # A meal's calendar events duplicate the meal itself, which has its own result.
            must_not: [{exists: {field: "meal_id"}}]
          }
        },
        highlight: {
          # HTML-escape the source text in fragments, since the views render them as raw HTML.
          encoder: "html",
          pre_tags: ["<mark>"],
          post_tags: ["</mark>"],
          fields: EXCERPT_FIELDS.index_with { {fragment_size: 200, number_of_fragments: 1} }
            .merge(TITLE_FIELDS.index_with { {} })
        }
      }
    end
    # rubocop:enable Metrics/MethodLength

    # The fields searched across all Gather indexed models, by how a match is shown to the user. Every
    # searched field is visible in the result somehow, so a hit is never unexplained.
    #
    # Shown as the result title. Also what title: searches.
    TITLE_FIELDS = %w[title name first_name last_name user_name].freeze
    # Shown in the title or details line (see SearchHelper).
    DETAIL_FIELDS = %w[species color make model plate relationship unit_num location].freeze
    # Prose shown as a highlighted excerpt below the details line.
    EXCERPT_FIELDS = %w[
      content description note notes guidelines obituary messages_body
      entrees side kids dessert vet health_issues caregivers
    ].freeze
    GATHER_FIELDS = (TITLE_FIELDS.map { |f| "#{f}^3" } + DETAIL_FIELDS + EXCERPT_FIELDS).freeze

    private

    # A quoted phrase (which keeps its spaces) must match exactly. A word that the analyzer splits
    # into several tokens, like "gluten-free", needs all of them in one field.
    def term_query(term, fields)
      type =
        if wildcard?(term)
          # Matches the words before the * exactly and the last one as a prefix.
          term = term.delete_suffix("*")
          {type: "phrase_prefix"}
        elsif term.include?(" ")
          {type: "phrase"}
        else
          {type: "best_fields", operator: "and"}
        end
      # lenient skips numeric fields like unit_num when the term isn't a number.
      {multi_match: {query: term, fields: fields, lenient: true, **type}}
    end

    def wildcard?(term)
      term.end_with?("*") && term.length > 1
    end

    # rubocop:disable Metrics/MethodLength
    def parse(raw)
      raw = raw.gsub(/title:"([^"]+)"/) {
              @title_terms << $1
              ""
            }
        .gsub(/title:(\S+)/) {
              @title_terms << $1
              ""
            }
        .gsub(/type:(\S+)/) {
              @type_filter = $1.downcase
              ""
            }
        .gsub(/"([^"]+)"/) {
        @full_text_terms << $1
        ""
      }
      @full_text_terms.concat(raw.split.reject(&:empty?))
    end
    # rubocop:enable Metrics/MethodLength

    def escape(term)
      term.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")
    end
  end
end
