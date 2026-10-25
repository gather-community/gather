# frozen_string_literal: true

module SearchHelper
  # Font Awesome 4 icon specs for each result kind; the keys double as the list of kinds.
  # String = regular icon; Hash = {name:, style:}.
  KIND_ICONS = {
    "wiki_page" => "info-circle",
    "event" => "ticket",
    "calendar" => "calendar",
    "group" => "users",
    "user" => "address-card",
    "household" => "home",
    "meal" => "cutlery",
    "memorial" => {name: "pagelines", style: :brands},
    "emergency_contact" => "phone",
    "pet" => "paw",
    "vehicle" => "car",
    "transaction" => "dollar"
  }.freeze

  # Labels live under search.kinds.* in config/locales/en/search.yml.
  def search_result_kind_label(kind)
    t("search.kinds.#{kind}") if KIND_ICONS.key?(kind)
  end

  def search_result_kind_icon(kind)
    icon_spec = KIND_ICONS[kind]
    return "".html_safe unless icon_spec
    name = icon_spec.is_a?(Hash) ? icon_spec[:name] : icon_spec
    style = icon_spec.is_a?(Hash) ? icon_spec[:style] : nil
    icon_tag(name, style: style, class: "result-kind-icon")
  end

  # Returns the hit's highlight fragments, or nil if none of the highlighted fields matched
  # (e.g. a person found by first name only, since names aren't highlighted).
  def search_result_highlight(result)
    result.highlight if result.highlight?
  end

  # Returns the highlighted body fragment to show under the title, if any. Transactions use their
  # description as the title, so it isn't repeated as the snippet.
  def search_result_snippet(kind, highlight)
    return nil if highlight.nil?
    fields = %i[content description note notes body]
    fields -= %i[description] if kind == "transaction"
    fields.lazy.filter_map { |f| highlight[f]&.first }.first
  end

  # Returns the display title for a search result given its kind and Elasticsearch _source.
  def search_result_title(kind, src, highlight)
    case kind
    when "user"
      "#{src.first_name} #{src.last_name}".strip
    when "transaction"
      highlighted(highlight&.description&.first) || src.description
    when "vehicle"
      parts = [src.make, src.model, src.color, src.plate].select(&:present?)
      parts.join(" ")
    else
      highlighted(highlight&.title&.first || highlight&.name&.first) ||
        src.title.presence || src.name.presence || t("search.untitled")
    end
  end

  # Returns the URL for a search result given its kind and Elasticsearch _source.
  # Returns nil if a URL cannot be determined.
  # rubocop:disable Metrics/MethodLength
  def search_result_url(kind, src)
    case kind
    when "wiki_page"
      wiki_page_path(slug: src.slug)
    when "event"
      calendars_event_path(src.id)
    when "calendar"
      # Calendars don't have a show page; link to their events
      calendars_events_path
    when "group"
      groups_group_path(src.id)
    when "user"
      user_path(src.id)
    when "household"
      household_path(src.id)
    when "meal"
      meal_path(src.id)
    when "memorial"
      people_memorial_path(src.id)
    when "emergency_contact", "pet", "vehicle"
      src.household_id.present? ? household_path(src.household_id) : nil
    when "transaction"
      # Link to statement if present, else billing accounts index
      src.statement_id.present? ? statement_path(src.statement_id) : accounts_path
    end
  rescue ActionController::UrlGenerationError
    nil
  end
  # rubocop:enable Metrics/MethodLength

  private

  # Marks a highlight fragment as safe. Elasticsearch has already HTML-escaped it (the query sets
  # `encoder: "html"`) and only added <mark> tags.
  def highlighted(fragment)
    fragment&.html_safe # rubocop:disable Rails/OutputSafety
  end
end
