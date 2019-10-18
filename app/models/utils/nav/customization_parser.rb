# frozen_string_literal: true

module Utils
  module Nav
    # Parses the top menu customization setting
    class CustomizationParser
      attr_accessor :markdown

      def initialize(markdown)
        # a nil input is stored as an empty string
        self.markdown = markdown || ""
      end

      def parse
        # scan the string for markdown-style links like [link-name](target)
        settings_topmenu = markdown.scan(%r{\[([\w\- ]+)\]\s*\(([\w/\.:%&\?=\-_\',\+@]+)\)})
        settings_topmenu.to_h
      end
    end
  end
end
