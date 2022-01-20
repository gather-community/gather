# frozen_string_literal: true

module CustomFields
  module Fields
    class MarkdownField < TextualField
      def type
        :markdown
      end
    end
  end
end
