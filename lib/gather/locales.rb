# frozen_string_literal: true

module Gather
  # The locales Gather supports and how a request's locale is chosen among them.
  # The full list lives in config/application.rb (config.i18n.available_locales).
  module Locales
    # Locales served to everyone. A locale is added once it is fully translated.
    RELEASED = %i[en].freeze

    # Locales whose translations were machine-generated and haven't been reviewed by people.
    MACHINE_TRANSLATED = %i[fr fr-CA es de sv nb fi nl it].freeze

    # Language subtags browsers send that should map to one of our locales.
    # Norwegian arrives as "no" (generic) or "nn" (Nynorsk) as well as "nb" (Bokmål).
    ALIASES = {"no" => "nb", "nn" => "nb"}.freeze

    FEATURE_FLAG = "i18n"

    def self.available
      I18n.available_locales
    end

    # The locale for a web request, chosen from the browser's Accept-Language header.
    # Unreleased locales are only offered to users with the i18n feature flag, so they can be tried out in
    # production before release.
    def self.for_request(accept_language, user:)
      locale = match(accept_language, available)
      if locale && RELEASED.exclude?(locale) && !preview?(user)
        locale = match(accept_language, RELEASED)
      end
      locale || I18n.default_locale
    end

    # Returns the locale in `eligible` that best fits an Accept-Language header, or nil if none does.
    # Preferences are tried in order of quality. For each, an exact match wins (fr-CA -> fr-CA), then the bare
    # language (fr-BE -> fr).
    def self.match(accept_language, eligible)
      by_tag = eligible.index_by { |locale| locale.to_s.downcase }
      preferred_tags(accept_language).each do |tag|
        language = tag.split("-").first
        locale = by_tag[tag] || by_tag[ALIASES.fetch(language, language)]
        return locale if locale
      end
      nil
    end

    # Language tags from an Accept-Language header, lowercased, most preferred first.
    def self.preferred_tags(accept_language)
      entries = accept_language.to_s.split(",").each_with_index.filter_map do |entry, index|
        tag, *params = entry.split(";").map(&:strip)
        quality = params.find { |p| p.start_with?("q=") }&.delete_prefix("q=")&.to_f || 1.0
        next if tag.blank? || tag == "*" || quality <= 0
        [tag.downcase, quality, index]
      end
      entries.sort_by { |_, quality, index| [-quality, index] }.map(&:first)
    end

    def self.preview?(user)
      user.present? && FeatureFlag.lookup(FEATURE_FLAG).on?(user)
    end
  end
end
