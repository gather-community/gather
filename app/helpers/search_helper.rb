# frozen_string_literal: true

module SearchHelper
  KIND_LABELS = {
    "wiki_page" => "Wiki",
    "event" => "Event",
    "calendar" => "Calendar",
    "group" => "Group",
    "user" => "Person",
    "household" => "Household",
    "meal" => "Meal",
    "memorial" => "Memorial",
    "emergency_contact" => "Emergency Contact",
    "pet" => "Pet",
    "vehicle" => "Vehicle",
    "transaction" => "Transaction"
  }.freeze

  # Font Awesome 4 icon specs for each kind. String = regular icon; Hash = {name:, style:}.
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

  def search_result_kind_label(kind)
    KIND_LABELS[kind]
  end

  def search_result_kind_icon(kind)
    icon_spec = KIND_ICONS[kind]
    return "".html_safe unless icon_spec
    name = icon_spec.is_a?(Hash) ? icon_spec[:name] : icon_spec
    style = icon_spec.is_a?(Hash) ? icon_spec[:style] : nil
    icon_tag(name, style: style, class: "result-kind-icon")
  end

  # Returns the display title for a search result given its kind and Elasticsearch _source.
  def search_result_title(kind, src, highlight)
    case kind
    when "user"
      hl = [highlight&.first_name&.first, highlight&.last_name&.first].compact
      hl.any? ? safe_join(hl, " ") : "#{src.first_name} #{src.last_name}".strip
    when "vehicle"
      parts = [src.make, src.model, src.color, src.plate].select(&:present?)
      parts.join(" ")
    else
      # rubocop:disable Rails/OutputSafety
      raw(highlight&.title&.first ||
          highlight&.name&.first ||
          src.title.presence ||
          src.name.presence ||
          "(untitled)")
      # rubocop:enable Rails/OutputSafety
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
end
