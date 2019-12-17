# frozen_string_literal: true

module Utils
  module Nav
    # Parses the top menu customization setting
    class CustomizationParser
      attr_accessor :markdown
      attr_accessor :customizations

      def initialize(markdown)
        # a nil input is stored as an empty string
        self.markdown = markdown || ""
        self.customizations = parse
      end

      def filter_item(item_hash)
        # check to see if this item has been customized
        translated_name = I18n.t("nav_links.main.#{item_hash[:name]}")
        if customizations[translated_name]
          item_hash[:path] = customizations[translated_name]
          customizations.delete(translated_name)
        end
        if item_hash[:path] == "none"
          nil
        else
          item_hash
        end
      end

      def extra_items
        result = []
        customizations.each do |c|
          result << {
            name: c[0],
            path: c[1],
            permitted: true,
            icon: "info-circle"
          }
        end
        result
      end

      def parse
        # scan the string for markdown-style links like [link-name](target)
        settings_topmenu = markdown.scan(%r{\[([\w\- ]+)\]\s*\(([\w/\.:%&\?=\-_\',\+@]+)\)})
        settings_topmenu.to_h
      end
    end
  end
end
