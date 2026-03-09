# frozen_string_literal: true

class SearchController < ApplicationController
  include GDrive::AuthUrlable

  before_action -> { nav_context(:search) }

  # All Gather models that are indexed in Elasticsearch.
  GATHER_MODELS = [
    Wiki::Page,
    Calendars::Event,
    Calendars::Calendar,
    Groups::Group,
    User,
    Household,
    Meals::Meal,
    People::Memorial,
    People::EmergencyContact,
    People::Pet,
    People::Vehicle,
    Billing::Transaction
  ].freeze

  ALL_TYPES = %w[
    wiki_page event calendar group user household meal
    memorial emergency_contact pet vehicle transaction
  ].freeze
  ALL_TYPES_WITH_DRIVE = (ALL_TYPES + ["drive"]).freeze

  # rubocop:disable Metrics/MethodLength
  def index
    authorize(:search)
    skip_policy_scope

    @query = params[:search].to_s.strip
    @types = parse_types

    respond_to do |format|
      format.html
      format.json do
        @parser = Search::QueryParser.new(@query) if @query.present?
        source = params[:source].to_s
        case source
        when "gather"
          results = fetch_gather_results
          html = render_to_string(partial: "results_gather", formats: [:html],
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
  # rubocop:enable Metrics/MethodLength

  private

  def parse_types
    raw = params[:types].to_s.split
    return ALL_TYPES_WITH_DRIVE if raw.empty?
    raw & ALL_TYPES_WITH_DRIVE
  end

  def gather_kinds
    @types & ALL_TYPES
  end

  def fetch_gather_results
    return [] if @parser.nil? || @parser.blank? || gather_kinds.empty?

    query = @parser.to_gather_query(
      community_id: current_community.id,
      kinds: (gather_kinds.length == ALL_TYPES.length) ? nil : gather_kinds
    )
    Elasticsearch::Model.search(query, GATHER_MODELS).results
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
