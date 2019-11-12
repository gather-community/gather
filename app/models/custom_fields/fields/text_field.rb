# frozen_string_literal: true

module CustomFields
  module Fields
    class TextField < TextualField
      def type
        :text
      end
    end
  end
end
