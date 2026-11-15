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
  # Drive file types, as filter values. See GDrive::Searcher::FILE_TYPES.
  DRIVE_TYPES = GDrive::Searcher::FILE_TYPES.map { |t| "drive_#{t}" }.freeze
  ALL_TYPES_WITH_DRIVE = (ALL_TYPES + DRIVE_TYPES).freeze

  # Gather results are shown this many at a time; "More results" loads the next page.
  PAGE_SIZE = 10
  # The most Gather hits fetched per search. The count shows "200+" beyond this.
  MAX_RESULTS = 200
  # How long a search's results are kept for "More results". Each page's records are still loaded
  # through the policy scopes, so a cached hit the user has since lost access to isn't shown.
  RESULTS_CACHE_EXPIRY = 15.minutes

  # rubocop:disable Metrics/MethodLength
  def index
    authorize(:search)
    raise Pundit::NotAuthorizedError unless FeatureFlag.lookup("search").on?(current_user)
    skip_policy_scope

    @query = params[:search].to_s.strip
    # Communities without a Google Drive connection get a Gather-only search page.
    @drive_available = GDrive::Config.exists?(community: current_community)
    @all_types = @drive_available ? ALL_TYPES_WITH_DRIVE : ALL_TYPES
    @types = parse_types

    respond_to do |format|
      format.html
      format.json do
        @parser = Search::QueryParser.new(@query) if @query.present?
        source = params[:source].to_s
        case source
        when "gather"
          render_gather_page
        when "drive"
          return head(:not_found) unless @drive_available

          render_drive_page
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  private

  # No types param means all types. A present but empty one means the user unchecked them all.
  def parse_types
    return @all_types unless params.key?(:types)
    params[:types].to_s.split & @all_types
  end

  # Renders one page of Gather results. The first page replaces the list; later pages are appended.
  # Every visible hit is needed for the count and paging, but only the page's records are loaded and
  # rendered (the details line can take extra queries per record).
  def render_gather_page
    visibility = Search::Visibility.new(user: current_user, community: current_community)
    offset = params[:offset].to_i.clamp(0, MAX_RESULTS)
    results, capped = cached_gather_results(visibility, offset)
    page = visibility.load_hits(results[offset, PAGE_SIZE] || [])
    next_offset = offset + PAGE_SIZE
    html = render_to_string(partial: "results_gather", formats: [:html],
      locals: {results: page, append: offset.positive?})
    render(json: {html: html, count: results.size, capped: capped,
                  next_offset: (next_offset < results.size) ? next_offset : nil})
  end

  def drive_searcher(config, wrapper, reader_email)
    GDrive::Searcher.new(wrapper: wrapper, reader_email: reader_email, parser: @parser,
      drive_ids: config.items.drives_only.pluck(:external_id), file_types: drive_file_types)
  end

  def drive_wrapper(config)
    GDrive::Wrapper.new(config: config, google_user_id: config.org_user_id,
      callback_url: gdrive_setup_auth_callback_url(host: Settings.url.host))
  end

  # Keyed by everything that changes the results: who's asking, where, the query (which includes any
  # type: filter), and the given extras, such as the checked types or the Google account searched as.
  def results_cache_key(source, *extras)
    ["search", source, current_user.id, current_community.id, Digest::SHA256.hexdigest(@query), *extras]
      .join("/")
  end

  # The checked Drive file types, e.g. %w[doc pdf].
  def drive_file_types
    (@types & DRIVE_TYPES).map { |t| t.delete_prefix("drive_") }
  end

  def gather_kinds
    @types & ALL_TYPES
  end

  # Renders one page of Drive results. Drive doesn't report a total, so while there are more pages the
  # count is the number found so far with a "+", e.g. "50+".
  def render_drive_page
    offset = [params[:offset].to_i, 0].max
    page = fetch_drive_page(offset)
    if page[:error] == :auth
      html = render_to_string(partial: "results_drive_auth_error", formats: [:html], locals: {})
      return render(json: {html: html, count: 0, next_offset: nil})
    end
    html = render_to_string(partial: "results_drive", formats: [:html],
      locals: {results: page[:files], append: offset.positive?})
    render(json: {html: html, count: page[:found], capped: page[:more],
                  next_offset: page[:more] ? offset + PAGE_SIZE : nil})
  end

  # A first page always searches fresh and caches the visible results. "More results" reuses them,
  # searching again only if the cache has expired.
  def cached_gather_results(visibility, offset)
    key = results_cache_key("gather", @types.sort.join(","))
    cached = Rails.cache.read(key) if offset.positive?
    if cached
      results = cached[:results].map { |h| Elasticsearch::Model::Response::Result.new(h) }
      return [results, cached[:capped]]
    end
    results, capped = fetch_gather_results(visibility)
    Rails.cache.write(key, {results: results.map(&:to_hash), capped: capped},
      expires_in: RESULTS_CACHE_EXPIRY)
    [results, capped]
  end

  # Returns the visible results (up to MAX_RESULTS) and whether Elasticsearch had more than that.
  def fetch_gather_results(visibility)
    return [[], false] if @parser.nil? || @parser.blank? || gather_kinds.empty?

    query = @parser.to_gather_query(
      community_id: current_community.id,
      kinds: (gather_kinds.length == ALL_TYPES.length) ? nil : gather_kinds,
      extra_filters: visibility.es_filters
    )
    results = Elasticsearch::Model.search(query.merge(size: MAX_RESULTS), GATHER_MODELS).results
    [visibility.filter(results), results.total > MAX_RESULTS]
  end

  def fetch_drive_page(offset)
    empty = {files: [], found: 0, more: false}
    return empty if @parser.nil? || @parser.blank?

    reader_email = current_user.google_email
    return empty if reader_email.blank?

    config = GDrive::Config.find_by(community: current_community)
    wrapper = config && drive_wrapper(config)
    return empty unless wrapper&.has_credentials?

    cache_key = results_cache_key("drive", reader_email, drive_file_types.sort.join(","))
    GDrive::PagedSearch.new(searcher: drive_searcher(config, wrapper, reader_email), cache_key: cache_key,
      page_size: PAGE_SIZE, expires_in: RESULTS_CACHE_EXPIRY).page(offset)
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
    # The community's Drive connection needs an admin to reauthorize. Users see a notice saying so.
    Gather::ErrorReporter.instance.report(e, data: {community_id: current_community.id})
    {error: :auth}
  end
end
