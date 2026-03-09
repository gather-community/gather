# frozen_string_literal: true

module Search
  # Parses a shared search query string into components usable by both
  # Elasticsearch and the Google Drive API.
  #
  # Supported syntax:
  #   solar panels            - full-text search for both words
  #   "solar panels"          - exact phrase match
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
      parts.concat(full_text_terms.map { |t| "fullText contains '#{escape(t)}'" })
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
    # Includes results where community_id matches (single-community models) OR
    # community_ids contains the ID (multi-community models like Groups::Group).
    # rubocop:disable Metrics/MethodLength
    def to_gather_query(community_id:, kinds: nil)
      must = []
      if full_text_terms.any?
        must << {
          multi_match: {
            query: full_text_terms.join(" "),
            fields: GATHER_FIELDS,
            type: "best_fields"
          }
        }
      end
      title_terms.each do |t|
        must << {multi_match: {query: t, fields: %w[title name], type: "best_fields"}}
      end

      community_filter = {
        bool: {
          should: [
            {term: {community_id: community_id}},
            {term: {community_ids: community_id}}
          ],
          minimum_should_match: 1
        }
      }

      filter = [community_filter]
      filter << {terms: {kind: kinds}} if kinds.present?

      {
        query: {
          bool: {
            filter: filter,
            must: must.presence || [{match_all: {}}]
          }
        },
        highlight: {
          pre_tags: ["<mark>"],
          post_tags: ["</mark>"],
          fields: {
            content: {fragment_size: 200, number_of_fragments: 1},
            description: {fragment_size: 200, number_of_fragments: 1},
            note: {fragment_size: 200, number_of_fragments: 1},
            notes: {fragment_size: 200, number_of_fragments: 1},
            title: {},
            name: {}
          }
        },
        size: 30
      }
    end
    # rubocop:enable Metrics/MethodLength

    # Fields searched across all Gather indexed models.
    # title/name weighted higher; body fields have default weight.
    GATHER_FIELDS = %w[
      title^3 name^3 first_name^3 last_name^3
      content description note notes body
      location address
      email relationship
      make model plate
      code unit_num
      mailman_list_name mailman_list_fqdn
      species color vet health_issues caregivers
    ].freeze

    private

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
