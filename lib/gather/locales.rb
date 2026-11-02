# frozen_string_literal: true

module Gather
  # The locales Gather supports and how a request's locale is chosen among them.
  # The full list lives in config/application.rb (config.i18n.available_locales).
  module Locales
    # Locales whose translations were machine-generated and haven't been reviewed by people. Pages and
    # emails in these locales say so.
    MACHINE_TRANSLATED = %i[fr fr-CA es de sv nb fi nl it].freeze

    # Locales with every key translated, which CI holds to that (spec/i18n_spec.rb) and smoke-tests
    # (spec/system/locale_smoke_spec.rb). A locale joins once its translation is finished.
    TRANSLATED = %i[en fr fr-CA es de sv nb fi nl it].freeze

    # Language subtags browsers send that should map to one of our locales.
    # Norwegian arrives as "no" (generic) or "nn" (Nynorsk) as well as "nb" (Bokmål).
    ALIASES = {"no" => "nb", "nn" => "nb"}.freeze

    # Turns on every locale other than the default. While it's off, everyone gets the default locale.
    # Switch it to the "user" interface to turn the locales on for just some people.
    FEATURE_FLAG = "i18n"

    # The cookie holding the locale someone picked from the footer's language menu. It wins over the browser's
    # Accept-Language header. With no cookie, the header decides.
    COOKIE = "locale"

    def self.available
      I18n.available_locales
    end

    # The locale for a web request: the one chosen in the language menu, if any, else the best match for the
    # browser's Accept-Language header. Only the default locale is served unless the feature flag is on.
    def self.for_request(accept_language, user:, chosen: nil)
      return I18n.default_locale unless enabled?(user)
      find(chosen) || match(accept_language, available) || I18n.default_locale
    end

    # The available locale whose code is `code` (a string from a cookie, say), or nil.
    def self.find(code)
      available.find { |locale| locale.to_s == code }
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

    # The Postgres ICU collation that sorts text as people expect in `locale`. The rules really differ:
    # Swedish, Finnish and Norwegian put å, ä and ö after z, while German sorts ä with a. English uses the
    # root collation, which sorts accented letters with their base letters ("Émile" with the Es).
    # See Gather::Collation.
    def self.collation(locale = I18n.locale)
      (locale.to_sym == :en) ? "und-x-icu" : "#{locale}-x-icu"
    end

    # Whether `user` (nil when signed out) gets locales other than the default. A "user"-interface flag needs
    # a user to check, so it's off for signed-out visitors.
    def self.enabled?(user)
      flag = FeatureFlag.lookup(FEATURE_FLAG)
      (flag.interface == "basic") ? flag.on? : (user.present? && flag.on?(user))
    end

    # The locales offered in the language menu, as [name, code] pairs sorted by name. Each is named in its
    # own language ("Français", "Deutsch"), as language menus usually are, so people can find theirs whatever
    # language the page is in.
    def self.menu_options
      options = available.map { |locale| [I18n.t("common.language_name", locale: locale), locale.to_s] }
      Collation.sort_by(options, &:first)
    end
  end
end
