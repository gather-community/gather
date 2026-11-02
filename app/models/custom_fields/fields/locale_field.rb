# frozen_string_literal: true

module CustomFields
  module Fields
    # One of the languages Gather is available in, stored as its locale code ("fr-CA"). The options are listed
    # in their own language ("Français (Canada)"), as language menus usually are.
    class LocaleField < EnumField
      def initialize(key:, **params)
        super(key: key, options: Gather::Locales.available.map(&:to_s), **params)
      end

      def type
        :locale
      end

      def collection
        Gather::Locales.menu_options.map(&:last)
      end

      def option_label(item)
        I18n.t("common.language_name", locale: item)
      end
    end
  end
end
