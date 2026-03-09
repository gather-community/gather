# frozen_string_literal: true

module Wiki
  class SearchController < ApplicationController
    include GDrive::AuthUrlable

    before_action -> { nav_context(:wiki, :search) }

    def index
      authorize(Wiki::Page.new(community: current_community), :show?, policy_class: Wiki::PagePolicy)
      skip_policy_scope

      prepare_lenses(:"wiki/search_source")

      @query = params[:search].to_s.strip

      respond_to do |format|
        format.html
        format.json do
          @parser = Search::QueryParser.new(@query) if @query.present?
          source = params[:source].to_s
          case source
          when "wiki"
            results = fetch_wiki_results
            html = render_to_string(partial: "results_wiki", formats: [:html],
                                    locals: {results: results, query: @query})
            render json: {html: html, count: results.count, next_page_token: nil}
          when "drive"
            drive_results = fetch_drive_results
            if drive_results[:error] == :auth
              html = render_to_string(partial: "results_drive_auth_error", formats: [:html], locals: {})
              render json: {html: html, count: 0, next_page_token: nil}
            else
              html = render_to_string(partial: "results_drive", formats: [:html],
                                      locals: {results: drive_results[:files]})
              render json: {html: html, count: drive_results[:files].length,
                            next_page_token: drive_results[:next_page_token]}
            end
          end
        end
      end
    end

    private

    def fetch_wiki_results
      return [] if @parser.nil? || @parser.blank?

      Wiki::Page.search(@parser.to_es_query(community_id: current_community.id)).results
    end

    def fetch_drive_results
      return {files: [], next_page_token: nil} if @parser.nil? || @parser.blank?

      reader_email = current_user.google_email
      return {files: [], next_page_token: nil} if reader_email.blank?

      config = GDrive::Config.find_by(community: current_community)
      return {files: [], next_page_token: nil} if config.nil?

      wrapper = GDrive::Wrapper.new(config: config, google_user_id: config.org_user_id,
                                    callback_url: gdrive_setup_auth_callback_url(host: Settings.url.host))
      return {files: [], next_page_token: nil} unless wrapper.has_credentials?

      drive_ids = config.items.drives_only.pluck(:external_id)
      searcher = GDrive::Searcher.new(wrapper: wrapper, reader_email: reader_email,
                                      drive_ids: drive_ids, parser: @parser)
      searcher.search(page_token: params[:page_token].presence)
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
      Rails.logger.error("GDrive authorization error during search: #{e.message}")
      {files: [], next_page_token: nil, error: :auth}
    end
  end
end
