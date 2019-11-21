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
        @done = []
      end

      def filter_item(name:, path:, permitted:, icon:)
        # check to see if this item has been customized
        result = {}
        result[:name] = name
        translated_name = I18n.t("nav_links.main.#{name}")
        if @customizations[translated_name]
          result[:path] = @customizations[translated_name]
          @done << translated_name
        else
          result[:path] = path
        end
        result[:permitted] = permitted
        result[:icon] = icon
        if result[:path] == "none"
          nil
        else
          result
        end
      end

      def each
        @customizations.each do |c|
          next if @done.include?(c[0])
          result = {}
          result[:name] = c[0]
          result[:path] = c[1]
          result[:permitted] = true
          result[:icon] = "info-circle"
          yield(result)
        end
      end

      def parse
        # scan the string for markdown-style links like [link-name](target)
        settings_topmenu = markdown.scan(%r{\[([\w\- ]+)\]\s*\(([\w/\.:%&\?=\-_\',\+@]+)\)})
        settings_topmenu.to_h
      end
    end
  end
end
