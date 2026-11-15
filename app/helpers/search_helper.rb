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

  # Returns the highlighted excerpt to show below the details line, if a prose field matched.
  # Transactions use their description as the title, so it isn't repeated as the excerpt.
  def search_result_excerpt(kind, highlight)
    return nil if highlight.nil?
    fields = Search::QueryParser::EXCERPT_FIELDS
    fields -= %w[description] if kind == "transaction"
    fields.lazy.filter_map { |f| highlight[f]&.first }.first
  end

  # Returns the facts shown after the kind label, e.g. a meal's time, place and head cook, joined by a
  # separator. Built from the database record, so it's current even if the index lags.
  def search_result_details(hit)
    record = hit.record.decorator_class? ? hit.record.decorate : hit.record
    parts = Array(send(:"#{hit.kind}_search_details", record)).compact_blank
    safe_join(parts, t("search.details.separator"))
  end

  # Returns the facts shown under a Google Drive file's name: its type and when it was last modified.
  def search_drive_file_details(file)
    type = Search::QueryParser::MIME_TYPES.key(file.mime_type)
    parts = [
      type ? t("search.details.drive_types.#{type}") : nil,
      file.modified_time ? t("search.details.modified", date: l(file.modified_time.to_date)) : nil
    ]
    safe_join(parts.compact, t("search.details.separator"))
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
    when "memorial"
      highlighted(highlight&.user_name&.first) || src.user_name.presence || t("search.untitled")
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
      calendar_events_path(src.id)
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
      # Link to the statement if there is one, else the account, which its household can see.
      src.statement_id.present? ? statement_path(src.statement_id) : account_path(src.account_id)
    end
  rescue ActionController::UrlGenerationError
    nil
  end
  # rubocop:enable Metrics/MethodLength

  private

  # Events show their date or dates, not times. A repeating event shows its pattern and date range, as
  # on its show page.
  def event_search_details(event)
    pattern = event.eventlets.first&.decorate&.recurrence_description(include_time: false)
    [pattern || search_date_range(event.starts_at.to_date, event.ends_at.to_date), event.calendar.name]
  end

  def search_date_range(first, last)
    return l(first) if first == last
    t("search.details.date_range", first: l(first), last: l(last))
  end

  def meal_search_details(meal)
    head_cook = meal.head_cook_name
    [meal.served_at_datetime, meal.location_name,
      head_cook && t("search.details.head_cook", name: head_cook)]
  end

  def wiki_page_search_details(page)
    date = l(page.updated_at.to_date)
    if page.updater
      t("search.details.updated_by", date: date, name: page.updater.decorate.name_with_inactive)
    else
      t("search.details.updated", date: date)
    end
  end

  def calendar_search_details(calendar)
    [calendar.group&.name]
  end

  def group_search_details(group)
    [t("simple_form.options.groups_group.kind.#{group.kind}"),
      t("simple_form.options.groups_group.availability.#{group.availability}"),
      t("search.details.members", count: group.members.size)]
  end

  def user_search_details(user)
    unit = user.household&.unit_num_and_suffix
    [user.household && search_household_name(user.household),
      unit && t("search.details.unit", unit: unit),
      user.adult? ? nil : t("search.details.child"),
      (user.community == current_community) ? nil : user.community.name]
  end

  def household_search_details(household)
    unit = household.unit_num_and_suffix
    # Through the user scope, so a visitor from another community doesn't see the names of children.
    members = Pundit.policy_scope!(current_user, User).where(household_id: household.id).active
      .by_name_adults_first.map(&:first_name)
    [unit && t("search.details.unit", unit: unit), members.to_sentence]
  end

  def memorial_search_details(memorial)
    [t("search.details.years", birth: memorial.birth_year, death: memorial.death_year)]
  end

  def emergency_contact_search_details(contact)
    [contact.relationship, search_household_name(contact.household)]
  end

  def pet_search_details(pet)
    species =
      if pet.color.present?
        t("search.details.pet_color_species", color: pet.color, species: pet.species)
      else
        pet.species
      end
    [species, search_household_name(pet.household)]
  end

  def vehicle_search_details(vehicle)
    [search_household_name(vehicle.household)]
  end

  def transaction_search_details(transaction)
    [l(transaction.incurred_on), format_money(transaction.value),
      search_household_name(transaction.account.household)]
  end

  def search_household_name(household)
    t("search.details.household", name: household.name)
  end

  # Marks a highlight fragment as safe. Elasticsearch has already HTML-escaped it (the query sets
  # `encoder: "html"`) and only added <mark> tags.
  def highlighted(fragment)
    fragment&.html_safe # rubocop:disable Rails/OutputSafety
  end
end
