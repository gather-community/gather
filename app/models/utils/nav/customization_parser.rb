# frozen_string_literal: true

module Utils
  module Nav
    # Parses the top menu customization setting
    class CustomizationParser
      attr_accessor :markdown_string

      def initialize(markdown_string)
        self.markdown_string = markdown_string
      end

      def parse
        settings_topmenu = markdown_string || ""
        settings_topmenu = settings_topmenu.scan(%r{\[([\w\- ]+)\]\s*\(([\w/\.:%&\?=\-_\',\+@]+)\)})
        settings_topmenu.to_h
      end
    end
  end
end
